# frozen_string_literal: true

# Live ESPN smoke — shared schema proof (not part of make test).
# Usage (from jumbotron/):
#   docker-compose run --rm -e RAILS_ENV=development engine \
#     bundle exec rails runner script/espn_live_smoke.rb

require "json"
require "time"

module EspnLiveSmoke
  module_function

  CASES = [
    {
      label: "NFL current",
      sport: "football",
      league: "nfl",
      scoreboard: {},
      teams: {},
      expect_week: :optional
    },
    {
      label: "NFL 2025 W1",
      sport: "football",
      league: "nfl",
      scoreboard: { dates: 2025, season_type: 2, week: 1 },
      teams: {},
      expect_week: :football
    },
    {
      label: "NCAA FB 2025 W1",
      sport: "football",
      league: "college-football",
      scoreboard: { dates: 2025, season_type: 2, week: 1 },
      teams: { limit: 200 },
      expect_week: :football
    },
    {
      label: "NHL 20251108",
      sport: "hockey",
      league: "nhl",
      scoreboard: { dates: 20_251_108 },
      teams: {},
      expect_week: :absent_ok
    },
    {
      label: "MLB 20250704",
      sport: "baseball",
      league: "mlb",
      scoreboard: { dates: 20_250_704 },
      teams: {},
      expect_week: :absent_ok
    },
    {
      label: "EPL 20250816",
      sport: "soccer",
      league: "eng.1",
      scoreboard: { dates: 20_250_816 },
      teams: {},
      expect_week: :absent_ok
    }
  ].freeze

  HARD_KEYS = %i[
    game_provider_id
    scheduled_at
    status_triad
    competitors
    team_provider_ids
    team_names
  ].freeze

  def run!
    puts("=" * 72)
    puts("ESPN live smoke — #{Time.now.utc.iso8601}")
    puts("Base: #{Jumbotron::Clients::Espn::DEFAULT_BASE_URL}")
    puts("=" * 72)

    results = CASES.map { |c| evaluate_case(c) }
    print_summary(results)

    hard_failures = results.select { |r| r[:verdict] == "GAP" || r[:verdict] == "FAIL" }
    exit(hard_failures.empty? ? 0 : 1)
  end

  def evaluate_case(c)
    row = {
      label: c[:label],
      sport: c[:sport],
      league: c[:league],
      scoreboard_params: c[:scoreboard],
      teams_params: c[:teams],
      expect_week: c[:expect_week],
      soft: [],
      hard: [],
      sample: {},
      verdict: "PASS"
    }

    board_result = Jumbotron::Clients.espn.scoreboard.get(
      sport: c[:sport],
      league: c[:league],
      **c[:scoreboard]
    )
    unless board_result.success?
      row[:hard] << "scoreboard_call: #{failure_detail(board_result)}"
      row[:verdict] = "FAIL"
      return row
    end

    teams_result = Jumbotron::Clients.espn.teams.get(
      sport: c[:sport],
      league: c[:league],
      **c[:teams]
    )
    unless teams_result.success?
      row[:hard] << "teams_call: #{failure_detail(teams_result)}"
      row[:verdict] = "FAIL"
      return row
    end

    board = board_result.output
    teams = teams_result.output
    events = board.events

    row[:sample][:event_count] = events.size
    row[:sample][:teams_count] = teams.size

    if events.empty?
      row[:soft] << "empty_scoreboard"
      check_teams_only!(row, teams)
      row[:verdict] = row[:hard].any? ? "GAP" : (row[:soft].any? ? "SOFT" : "PASS")
      return row
    end

    event = events.first
    competition = event.competitions.first
    status = competition&.status
    competitors = competition&.competitors || []

    row[:sample].merge!(
      event_id: event.id,
      event_date: event.date,
      event_name: event.name,
      week: event.week&.number,
      season_year: event.season&.year,
      season_type: event.season&.type,
      competition_id: competition&.id,
      status_name: status&.type_name,
      status_state: status&.type_state,
      status_completed: status&.type_completed,
      neutral_site: competition&.neutral_site,
      venue_id: competition&.venue&.id,
      venue_name: competition&.venue&.full_name,
      competitors: competitors.map { |comp|
        {
          home_away: comp.home_away,
          score: comp.score,
          team_id: comp.team&.id,
          team_display_name: comp.team&.display_name
        }
      },
      teams_sample: teams.first(3).map { |t| { id: t.id, display_name: t.display_name } }
    )

    check_scoreboard!(row, event, competition, status, competitors, c[:expect_week])
    check_teams_only!(row, teams)

    row[:verdict] =
      if row[:hard].any?
        "GAP"
      elsif row[:soft].any?
        "SOFT"
      else
        "PASS"
      end

    row
  rescue StandardError => e
    row[:hard] << "exception: #{e.class}: #{e.message}"
    row[:verdict] = "FAIL"
    row
  end

  def check_scoreboard!(row, event, competition, status, competitors, expect_week)
    row[:hard] << "game_provider_id" if blank?(event.id) && blank?(competition&.id)
    date = event.date.presence || competition&.date.presence || competition&.start_date.presence
    if blank?(date)
      row[:hard] << "scheduled_at"
    elsif !parseable_time?(date)
      row[:hard] << "scheduled_at_unparseable:#{date}"
    end

    if status.nil? || blank?(status.type_name) || blank?(status.type_state) || status.type_completed.nil?
      row[:hard] << "status_triad"
    end

    if competitors.length < 2
      row[:hard] << "competitors_count:#{competitors.length}"
    else
      competitors.each_with_index do |comp, i|
        row[:hard] << "competitor[#{i}].home_away" if blank?(comp.home_away)
        row[:hard] << "competitor[#{i}].team.id" if blank?(comp.team&.id)
        if blank?(comp.team&.display_name) && blank?(comp.team&.name)
          row[:hard] << "competitor[#{i}].team.name"
        end
      end
    end

    if competition&.venue
      row[:soft] << "venue_missing_id" if blank?(competition.venue.id)
      row[:soft] << "venue_missing_name" if blank?(competition.venue.full_name)
    else
      row[:soft] << "venue_absent"
    end

    case expect_week
    when :football
      row[:soft] << "week_absent_on_football" if event.week.nil? || event.week.number.nil?
    when :absent_ok
      row[:soft] << "week_absent_expected" if event.week.nil?
    end
  end

  def check_teams_only!(row, teams)
    if teams.empty?
      row[:hard] << "teams_empty"
      return
    end

    sample = teams.first(5)
    sample.each_with_index do |team, i|
      row[:hard] << "teams[#{i}].id" if blank?(team.id)
      if blank?(team.display_name) && blank?(team.name)
        row[:hard] << "teams[#{i}].name"
      end
    end
  end

  def blank?(value)
    value.nil? || (value.respond_to?(:empty?) && value.empty?)
  end

  def parseable_time?(value)
    Time.iso8601(value.to_s)
    true
  rescue ArgumentError
    begin
      Time.parse(value.to_s)
      true
    rescue ArgumentError, TypeError
      false
    end
  end

  def failure_detail(result)
    err = result.error
    meta = result.metadata
    parts = []
    parts << "error=#{err.class}:#{err.message}" if err
    parts << "metadata=#{meta.inspect}" if meta && !meta.empty?
    parts << "output=#{result.output.class}" if result.output
    parts.join(" ")
  end

  def print_summary(results)
    results.each do |r|
      puts("-" * 72)
      puts("#{r[:verdict]}  #{r[:label]}  (#{r[:sport]}/#{r[:league]})")
      puts("  scoreboard params: #{r[:scoreboard_params].inspect}")
      puts("  teams params:      #{r[:teams_params].inspect}")
      unless r[:sample].empty?
        puts("  events=#{r[:sample][:event_count]} teams=#{r[:sample][:teams_count]}")
        puts("  sample: #{JSON.generate(r[:sample])}")
      end
      puts("  HARD: #{r[:hard].join(', ')}") if r[:hard].any?
      puts("  SOFT: #{r[:soft].join(', ')}") if r[:soft].any?
    end

    puts("=" * 72)
    puts("VERDICT TABLE")
    results.each do |r|
      puts(format("  %-18s %-6s hard=%d soft=%d", r[:label], r[:verdict], r[:hard].size, r[:soft].size))
    end

    overall =
      if results.any? { |r| %w[GAP FAIL].include?(r[:verdict]) }
        "NOT_ENOUGH_OR_FAILED"
      elsif results.any? { |r| r[:verdict] == "SOFT" }
        "ENOUGH_WITH_EXPECTED_SOFT_GAPS"
      else
        "ENOUGH"
      end
    puts("OVERALL_DB_SUFFICIENCY=#{overall}")
    puts("=" * 72)
  end
end

EspnLiveSmoke.run!
