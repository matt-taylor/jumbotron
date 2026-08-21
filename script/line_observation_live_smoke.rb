# frozen_string_literal: true

# Live 3.2 odds ingest smoke — acquire ESPN Core odds, translate, persist NFL, retrieve.
# Not part of make test.
# Usage (from jumbotron/):
#   docker-compose run --rm -e RAILS_ENV=development engine \
#     bundle exec rails runner script/line_observation_live_smoke.rb

require "json"
require "time"

module LineObservationLiveSmoke
  module_function

  ACQUIRE_CASES = [
    {
      label: "NFL 2025 W1",
      sport: "football",
      league: "nfl",
      scoreboard: { dates: 2025, season_type: 2, week: 1 },
      persist: true
    },
    {
      label: "EPL 20250816",
      sport: "soccer",
      league: "eng.1",
      scoreboard: { dates: 20_250_816 },
      persist: false
    },
    {
      label: "NHL 20251108",
      sport: "hockey",
      league: "nhl",
      scoreboard: { dates: 20_251_108 },
      persist: false
    }
  ].freeze

  def run!
    puts("=" * 72)
    puts("Line observation live smoke — #{Time.now.utc.iso8601}")
    puts("=" * 72)

    Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered?

    results = ACQUIRE_CASES.map { |c| evaluate_case(c) }
    results.each { |row| print_row(row) }

    hard_fail = results.any? { |r| r[:verdict] == "FAIL" }
    persist_fail = results.any? { |r| r[:persist] == "FAIL" }
    puts("-" * 72)
    if hard_fail || persist_fail
      puts "OVERALL: FAIL"
      exit 1
    end

    puts "OVERALL: PASS"
  end

  def evaluate_case(config)
    row = {
      label: config[:label],
      acquire: "SKIP",
      transform: "SKIP",
      persist: config[:persist] ? "SKIP" : "N/A",
      retrieve: config[:persist] ? "SKIP" : "N/A",
      notes: [],
      verdict: "PASS"
    }

    board = Jumbotron::Clients.espn.scoreboard.get(
      sport: config[:sport],
      league: config[:league],
      **config[:scoreboard]
    )
    unless board.success?
      return fail_row(row, "scoreboard: #{board.error&.message}")
    end

    event = Array(board.output.events).first
    if event.nil?
      return fail_row(row, "scoreboard empty")
    end

    competition = event.competitions&.first
    if competition.nil? || event.id.blank? || competition.id.blank?
      return fail_row(row, "missing event/competition id")
    end

    odds = Jumbotron::Providers::Espn::Resources::CompetitionOdds.acquire(
      sport: config[:sport],
      league: config[:league],
      event_id: event.id,
      competition_id: competition.id
    )
    unless odds.success?
      return fail_row(row, "odds acquire: #{odds.error&.message}")
    end

    row[:acquire] = "PASS"
    row[:notes] << "event=#{event.id} books=#{Array(odds.output.items).size}"

    ingest = Jumbotron::Adapters::Espn::NflHelpers::CompetitionOdds.call(
      odds.output,
      observed_at: Time.current,
      event_id: event.id,
      competition_id: competition.id
    )
    row[:transform] = "PASS"
    row[:notes] << "observations=#{ingest.observations.size}"

    if config[:persist]
      persist_nfl!(row, ingest, config)
    end

    row
  rescue StandardError => e
    fail_row(row, "#{e.class}: #{e.message}")
  end

  def persist_nfl!(row, ingest, config)
    league_result = Jumbotron::Services::Adapters::EnsureLeague.call(adapter: Jumbotron::Adapters::Espn::Nfl)
    unless league_result.success?
      row[:persist] = "FAIL"
      row[:verdict] = "FAIL"
      row[:notes] << "ensure league failed"
      return
    end

    sync = Jumbotron::Workflows::SynchronizeAdapterWorkflow.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      league_id: league_result.data[:league].id,
      observed_at: Time.current,
      acquisition: config[:scoreboard]
    )
    unless sync.success?
      row[:persist] = "FAIL"
      row[:verdict] = "FAIL"
      row[:notes] << "game sync failed: #{Array(sync.errors).map(&:message).join(';')}"
      return
    end

    result = Jumbotron::Services::Canonical::PersistLineObservations.call(ingest: ingest)
    unless result.success?
      row[:persist] = "FAIL"
      row[:verdict] = "FAIL"
      row[:notes] << "persist failed: #{Array(result.errors).map(&:message).join(';')}"
      return
    end

    row[:persist] = "PASS"
    row[:notes] << "created=#{result.data[:observations_created]} updated=#{result.data[:observations_updated]}"

    event_ref = ingest.game_identities.find { |ref| ref.namespace == "event" }
    identity = Jumbotron::ProviderIdentity.find_by(
      provider: event_ref.provider,
      object_namespace: event_ref.namespace,
      provider_id: event_ref.id
    )
    game = identity&.target
    count = game.is_a?(Jumbotron::Game) ? Jumbotron::LineObservation.where(game: game).count : 0
    sample = Jumbotron::LineObservation.where(game: game).limit(3).map do |obs|
      "#{obs.market}/#{obs.outcome}/#{obs.source}/#{obs.line_value}/#{obs.price_american}"
    end
    if count.positive?
      row[:retrieve] = "PASS"
      row[:notes] << "retrieved=#{count} sample=#{sample.join('|')}"
    else
      row[:retrieve] = "FAIL"
      row[:verdict] = "FAIL"
      row[:notes] << "no LineObservation rows retrieved"
    end
  end

  def fail_row(row, message)
    row[:verdict] = "FAIL"
    row[:notes] << message
    row[:acquire] = "FAIL" if row[:acquire] == "SKIP"
    row
  end

  def print_row(row)
    puts format(
      "%-16s acquire=%-4s transform=%-4s persist=%-4s retrieve=%-4s notes=%s",
      row[:label],
      row[:acquire],
      row[:transform],
      row[:persist],
      row[:retrieve],
      row[:notes].join("; ")
    )
  end
end

LineObservationLiveSmoke.run!
