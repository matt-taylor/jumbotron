# frozen_string_literal: true

# Fixture Game Progress smoke — transform + persist + public read (not live ESPN, not in make test).
# Usage (from jumbotron/):
#   docker-compose run --rm -e RAILS_ENV=development engine \
#     bundle exec rails runner script/game_progress_fixture_smoke.rb

require "json"
require File.expand_path("../spec/support/fake_transport", __dir__)

module GameProgressFixtureSmoke
  module_function

  def run!
    Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered?

    puts("=" * 72)
    puts("Game Progress fixture smoke — #{Time.now.utc.iso8601}")
    puts("=" * 72)

    rows = [
      transform_case("scheduled", scheduled_body, expect_nil: true),
      transform_case("completed W1", completed_body, expect_kind: "quarter", expect_number: 4),
      transform_case("overlaid Q3", overlaid_body("status_in_progress_q3.json"), expect_kind: "quarter",
                                                                               expect_number: 3),
      transform_case("overlaid intermission", overlaid_body("status_halftime.json"), expect_state: "intermission",
                                                                                    expect_kind: "quarter",
                                                                                    expect_number: 2,
                                                                                    expect_clock_nil: true),
      transform_case("overlaid OT", overlaid_body("status_overtime.json"), expect_kind: "overtime", expect_number: 1)
    ]
    persist_row = persist_completed!

    rows.each { |row| puts(format_row(row)) }
    puts persist_row
    puts("-" * 72)

    failed = rows.any? { |row| row[:status] == "FAIL" } || persist_row.start_with?("PERSIST FAIL")
    puts(failed ? "OVERALL: FAIL" : "OVERALL: PASS")
    exit(failed ? 1 : 0)
  end

  def fixture_root
    Jumbotron::Engine.root.join("spec/fixtures/espn/nfl")
  end

  def scheduled_body
    fixture_root.join("scoreboard_2026_pre.json").read
  end

  def completed_body
    fixture_root.join("scoreboard_2025_w1.json").read
  end

  def overlaid_body(status_file)
    payload = JSON.parse(completed_body)
    payload["events"].first["competitions"].first["status"] =
      JSON.parse(fixture_root.join("progress", status_file).read)
    payload.to_json
  end

  def acquire_board(body)
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(status: 200, body: body, duration_ms: 1)
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))
    Jumbotron::Clients.espn.scoreboard.get(sport: "football", league: "nfl").output
  end

  def transform_case(label, body, expect_nil: false, expect_state: "active", expect_kind: nil, expect_number: nil,
                     expect_clock_nil: false)
    Jumbotron::Clients.reset_providers!
    board = acquire_board(body)
    input = Jumbotron::Adapters::Espn::NflHelpers::Scoreboard.call(board, observed_at: Time.utc(2026, 8, 20, 18, 0, 0))
    progress = input.games.first.progress
    notes = [describe_progress(progress)]
    status = progress_matches?(progress, expect_nil:, expect_state:, expect_kind:, expect_number:, expect_clock_nil:)
    { label: label, status: status, notes: notes }
  rescue StandardError => e
    { label: label, status: "FAIL", notes: ["#{e.class}: #{e.message}"] }
  end

  def describe_progress(progress)
    return "progress=nil" if progress.nil?

    clock = progress.clock
    clock_text = if clock.nil?
                   "clock=nil"
                 else
                   "#{clock.mode}/#{clock.seconds}/#{clock.display}"
                 end
    "#{progress.state} #{progress.segment.kind}/#{progress.segment.number} #{clock_text}"
  end

  def progress_matches?(progress, expect_nil:, expect_state:, expect_kind:, expect_number:, expect_clock_nil:)
    return "FAIL" if expect_nil && !progress.nil?
    return "PASS" if expect_nil
    return "FAIL" if progress.nil?
    return "FAIL" if expect_state && progress.state != expect_state
    return "FAIL" if expect_kind && progress.segment.kind != expect_kind
    return "FAIL" if expect_number && progress.segment.number != expect_number
    return "FAIL" if expect_clock_nil && !progress.clock.nil?

    "PASS"
  end

  def persist_completed!
    Jumbotron::Clients.reset_providers!
    acquire_board(completed_body)
    sport = Jumbotron::Sport.find_or_create_by!(name: "football")
    league = Jumbotron::League.find_or_create_by!(sport: sport, name: "nfl")
    sync = Jumbotron::Workflows::SynchronizeAdapterWorkflow.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      league_id: league.id,
      observed_at: Time.utc(2026, 8, 20, 18, 0, 0),
      acquisition: { dates: 2025, season_type: 2, week: 1 }
    )
    return "PERSIST FAIL: #{Array(sync.errors).map(&:inspect).join(', ')}" unless sync.success?

    game = Jumbotron::Game.find(sync.payload[:games].first.id)
    public_game = Jumbotron.client.game(id: game.id)
    progress = public_game.progress
    return "PERSIST FAIL: public progress nil" if progress.nil?

    kind = progress.segment.kind
    number = progress.segment.number
    return "PERSIST FAIL: expected quarter 4, got #{kind}/#{number}" unless kind == "quarter" && number == 4

    "PERSIST PASS game_id=#{game.id} public=#{describe_progress(progress)} " \
      "observed_at=#{game.observed_at.utc.iso8601}"
  rescue StandardError => e
    "PERSIST FAIL: #{e.class}: #{e.message}"
  end

  def format_row(row)
    format("%-24s %s  %s", row[:label], row[:status], row[:notes].join("; "))
  end
end

GameProgressFixtureSmoke.run!
