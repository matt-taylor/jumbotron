# frozen_string_literal: true

# Live 3.3 line-update smoke — execution path + Current Lines + Consensus.
# Not part of make test.
# Usage (from jumbotron/):
#   docker-compose run --rm -e RAILS_ENV=development engine \
#     bundle exec rails runner script/line_update_live_smoke.rb

require "json"
require "time"

module LineUpdateLiveSmoke
  module_function

  def run!
    puts("=" * 72)
    puts("Line update live smoke — #{Time.now.utc.iso8601}")
    puts("=" * 72)

    adapter = Jumbotron::Adapters::Espn::Nfl
    adapter.register! unless adapter.registered?

    league_result = Jumbotron::Services::Adapters::EnsureLeague.call(adapter: adapter)
    abort_fail("ensure league failed") unless league_result.success?

    sync = Jumbotron::Workflows::SynchronizeAdapterWorkflow.call(
      adapter: adapter,
      endpoint: :scoreboard,
      league_id: league_result.data[:league].id,
      observed_at: Time.current,
      acquisition: { dates: 2025, season_type: 2, week: 1 }
    )
    abort_fail("game sync failed: #{Array(sync.errors).map { |e| e.respond_to?(:message) ? e.message : e }}") unless sync.success?

    game = Jumbotron::Game.joins(:provider_identities).where(
      jumbotron_provider_identities: { provider: "espn", object_namespace: "event" }
    ).first
    abort_fail("no canonical Game with ESPN event identity") if game.nil?

    scope = adapter.line_acquisition_scope_for(game)
    abort_fail("incomplete line acquisition scope") if scope.nil?

    executed = Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope.call(
      adapter: adapter,
      acquisition: scope.fetch(:acquisition)
    )
    abort_fail("execute failed: #{executed.data[:outcome]} #{executed.errors}") unless executed.success? && executed.data[:outcome] == :succeeded

    event_id = scope.fetch(:acquisition).fetch(:event_id)
    observations = Jumbotron::LineObservation.where(game: game)
    abort_fail("no LineObservation rows") if observations.none?

    currents = Jumbotron::Services::Canonical::ResolveCurrentLines.call(game: game)
    abort_fail("current lines failed") unless currents.success?

    consensus = Jumbotron::Services::Canonical::DeriveConsensusLine.call(game: game)
    abort_fail("consensus failed") unless consensus.success?

    current_lines = Array(currents.data[:current_lines])
    consensus_lines = Array(consensus.data[:consensus_lines])
    sample_current = current_lines.first(3).map do |line|
      "#{line.market}/#{line.outcome}/#{line.line_value}/#{line.price_american}"
    end
    sample_consensus = consensus_lines.first(3).map do |line|
      "#{line.market}/#{line.outcome}/#{line.line_value}/n=#{line.constituent_count}"
    end

    puts "event_id=#{event_id}"
    puts "bookmakers=#{observations.distinct.count(:bookmaker_id)}"
    puts "observations=#{observations.count}"
    puts "current_lines=#{current_lines.size} sample=#{sample_current.join('|')}"
    puts "consensus_groups=#{consensus_lines.size} sample=#{sample_consensus.join('|')}"
    puts "constituents=#{consensus_lines.sum(&:constituent_count)}"
    puts "OVERALL: PASS"
  end

  def abort_fail(message)
    puts "FAIL: #{message}"
    puts "OVERALL: FAIL"
    exit 1
  end
end

LineUpdateLiveSmoke.run!
