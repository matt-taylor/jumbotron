# frozen_string_literal: true

# Live adapter translation smoke — acquire → transform sufficiency (not part of make test).
# Usage (from jumbotron/):
#   docker-compose run --rm -e RAILS_ENV=development engine \
#     bundle exec rails runner script/adapter_translation_live_smoke.rb
#
# Optional: PERSIST=1 also runs SynchronizeAdapterWorkflow against a seeded League.

require "time"

module AdapterTranslationLiveSmoke
  module_function

  CASES = [
    {
      label: "NFL scoreboard current",
      endpoint: :scoreboard,
      acquisition: {}
    },
    {
      label: "NFL scoreboard 2025 W1",
      endpoint: :scoreboard,
      acquisition: { dates: 2025, season_type: 2, week: 1 }
    },
    {
      label: "NFL teams",
      endpoint: :teams,
      acquisition: {}
    }
  ].freeze

  def run!
    puts("=" * 72)
    puts("Adapter translation live smoke — #{Time.now.utc.iso8601}")
    puts("Adapter: #{Jumbotron::Adapters::Espn::Nfl.name}")
    puts("=" * 72)

    Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered?

    results = CASES.map { |c| evaluate_case(c) }
    persist_note = maybe_persist!(results)

    puts
    puts("-" * 72)
    results.each do |row|
      puts format(
        "%-28s acquire=%-4s transform=%-4s checklist=%-4s notes=%s",
        row[:label],
        row[:acquire],
        row[:transform],
        row[:checklist],
        row[:notes].join("; ").presence || "-"
      )
    end
    puts persist_note if persist_note
    puts("-" * 72)

    hard_fail = results.any? { |r| r[:acquire] == "FAIL" || r[:transform] == "FAIL" || r[:checklist] == "FAIL" }
    if hard_fail
      puts "OVERALL: FAIL"
      exit 1
    end

    soft = results.any? { |r| r[:checklist] == "SOFT" }
    puts soft ? "OVERALL: PASS_WITH_SOFT_NOTES" : "OVERALL: PASS"
  end

  def evaluate_case(config)
    notes = []
    adapter = Jumbotron::Adapters::Espn::Nfl
    operation = adapter.operation(config[:endpoint])
    observed_at = Time.current

    result = operation.acquire(**config[:acquisition])
    unless result.success?
      return row(config, "FAIL", "SKIP", "FAIL", ["acquisition: #{result.error&.message}"])
    end

    begin
      input = operation.transform(result.output, observed_at: observed_at)
    rescue Jumbotron::Adapters::TransformError => e
      return row(config, "PASS", "FAIL", "FAIL", ["transform: #{e.message}"])
    end

    checklist, check_notes = checklist_for(config[:endpoint], input)
    notes.concat(check_notes)
    row(config, "PASS", "PASS", checklist, notes)
  rescue StandardError => e
    row(config, "FAIL", "FAIL", "FAIL", ["#{e.class}: #{e.message}"])
  end

  def checklist_for(endpoint, input)
    notes = []
    return ["FAIL", ["expected SyncInput"]] unless input.is_a?(Jumbotron::Canonical::SyncInput)

    case endpoint
    when :scoreboard
      if input.games.empty?
        return ["SOFT", ["empty board — soft OK for current window"]]
      end

      input.games.each_with_index do |game, idx|
        unless Jumbotron::Game::LIFECYCLES.include?(game.lifecycle)
          return ["FAIL", ["game[#{idx}] bad lifecycle #{game.lifecycle.inspect}"]]
        end
        return ["FAIL", ["game[#{idx}] scheduled_at missing"]] if game.scheduled_at.nil?
        if game.provider_identities.none? { |r| %w[event competition].include?(r.namespace) }
          return ["FAIL", ["game[#{idx}] missing event/competition PI"]]
        end
        if game.participants.length != 2
          return ["FAIL", ["game[#{idx}] expected 2 participants"]]
        end
        roles = game.participants.map(&:role)
        unless roles.sort == %w[away home]
          return ["FAIL", ["game[#{idx}] roles=#{roles.inspect}"]]
        end
        game.participants.each do |p|
          return ["FAIL", ["participant missing team PI"]] if p.provider_identities.empty?
          return ["FAIL", ["participant missing name"]] if p.team_name.blank?
        end
      end
      notes << "#{input.games.size} games"
      ["PASS", notes]
    when :teams
      return ["FAIL", ["no teams"]] if input.teams.empty?

      input.teams.each_with_index do |team, idx|
        return ["FAIL", ["team[#{idx}] missing PI"]] if team.provider_identities.empty?
        return ["FAIL", ["team[#{idx}] missing name"]] if team.name.blank?
      end
      notes << "#{input.teams.size} teams"
      ["PASS", notes]
    else
      ["FAIL", ["unknown endpoint"]]
    end
  end

  def maybe_persist!(results)
    return nil unless ENV["PERSIST"] == "1"

    league = begin
      sport = Jumbotron::Sport.find_or_create_by!(name: "Football")
      Jumbotron::League.find_or_create_by!(sport: sport, name: "NFL")
    end

    adapter = Jumbotron::Adapters::Espn::Nfl
    sync = Jumbotron::Workflows::SynchronizeAdapterWorkflow.call(
      adapter: adapter,
      endpoint: :scoreboard,
      league_id: league.id,
      observed_at: Time.current,
      acquisition: { dates: 2025, season_type: 2, week: 1 }
    )
    raise "persist sync failed: #{sync.errors}" unless sync.success?

    "PERSIST=1 OK league_id=#{league.id} games=#{sync.payload[:games].size} batch=#{sync.payload[:observation_batch_id]}"
  rescue StandardError => e
    "PERSIST=1 FAIL: #{e.class}: #{e.message}"
  end

  def row(config, acquire, transform, checklist, notes)
    {
      label: config[:label],
      acquire: acquire,
      transform: transform,
      checklist: checklist,
      notes: notes
    }
  end
end

AdapterTranslationLiveSmoke.run!
