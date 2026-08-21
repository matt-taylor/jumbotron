# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::SelectEligibleGames do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.utc(2026, 8, 13, 18, 0, 0) }
  let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
  let(:policy) { adapter.policy(:upcoming) }
  let(:sport) { create(:jumbotron_sport, name: "football") }
  let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
  let(:season) { create(:jumbotron_season, league: league, name: "2025") }
  let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }

  before do
    adapter.register! unless adapter.registered?
  end

  def week_group(number)
    Jumbotron::ScheduleGroup.find_or_create_by!(
      season_id: season.id,
      season_phase_id: phase.id,
      kind: "week",
      name: "Week #{number}"
    ) do |group|
      group.number = number
    end
  end

  def build_game(scheduled_at:, lifecycle: "scheduled", group: week_group(4))
    create(
      :jumbotron_game,
      league: league,
      season: season,
      season_phase: phase,
      schedule_group: group,
      scheduled_at: scheduled_at,
      lifecycle: lifecycle
    )
  end

  around { |example| travel_to(now) { example.run } }

  it "fails when the catalog league is missing" do
    result = described_class.call(adapter: adapter, policy: policy, now: now)

    expect(result).to be_failure
    expect(result.errors.first.code).to eq("league_not_found")
  end

  it "returns an empty games list when none are eligible" do
    league
    result = described_class.call(adapter: adapter, policy: policy, now: now)

    expect(result).to be_success
    expect(result.data[:games]).to eq([])
    expect(result.data[:league]).to eq(league)
  end

  it "treats adapter eligible? as the authority including terminal games" do
    upcoming = build_game(scheduled_at: now + 1.week)
    build_game(scheduled_at: now + 8.weeks)
    completed = build_game(scheduled_at: now - 1.hour, lifecycle: "completed", group: week_group(3))

    result = described_class.call(adapter: adapter, policy: policy, now: now)

    expect(result).to be_success
    expect(result.data[:games]).to eq([upcoming])
    expect(result.data[:games]).not_to include(completed)
  end

  it "includes season, season_phase, and schedule_group" do
    game = build_game(scheduled_at: now + 1.week)

    result = described_class.call(adapter: adapter, policy: policy, now: now)
    loaded = result.data[:games].find { |row| row.id == game.id }

    expect(loaded.association(:season)).to be_loaded
    expect(loaded.association(:season_phase)).to be_loaded
    expect(loaded.association(:schedule_group)).to be_loaded
  end
end
