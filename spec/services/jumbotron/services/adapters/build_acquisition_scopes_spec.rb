# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::BuildAcquisitionScopes do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.utc(2026, 8, 13, 18, 0, 0) }
  let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
  let(:sport) { create(:jumbotron_sport, name: "football") }
  let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
  let(:season) { create(:jumbotron_season, league: league, name: "2025") }
  let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }

  before { adapter.register! unless adapter.registered? }

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

  def build_game(scheduled_at:, group: week_group(4))
    create(
      :jumbotron_game,
      league: league,
      season: season,
      season_phase: phase,
      schedule_group: group,
      scheduled_at: scheduled_at,
      lifecycle: "scheduled"
    )
  end

  around { |example| travel_to(now) { example.run } }

  it "asks the adapter for each game's acquisition scope" do
    game = build_game(scheduled_at: now + 1.week)
    allow(adapter).to receive(:acquisition_scope_for).and_call_original

    result = described_class.call(adapter: adapter, games: [game])

    expect(result).to be_success
    expect(adapter).to have_received(:acquisition_scope_for).with(game)
    expect(result.data[:scopes].size).to eq(1)
    expect(result.data[:skipped_incomplete_scope]).to eq(0)
  end

  it "counts nil adapter scopes as incomplete" do
    game = build_game(scheduled_at: now + 1.week, group: nil)

    result = described_class.call(adapter: adapter, games: [game])

    expect(result).to be_success
    expect(result.data[:scopes]).to eq([])
    expect(result.data[:skipped_incomplete_scope]).to eq(1)
  end

  it "deduplicates games that share a schedule group" do
    group4 = week_group(4)
    group5 = week_group(5)
    games = [
      build_game(scheduled_at: now + 1.week, group: group4),
      build_game(scheduled_at: now + 8.days, group: group4),
      build_game(scheduled_at: now + 9.days, group: group5)
    ]

    result = described_class.call(adapter: adapter, games: games)

    expect(result.data[:scopes].size).to eq(2)
    expect(result.data[:skipped_incomplete_scope]).to eq(0)
  end

  it "contains no ESPN query-parameter literals" do
    source = File.read(Jumbotron::Engine.root.join(
                         "app/services/jumbotron/services/adapters/build_acquisition_scopes.rb"
                       ))
    expect(source).not_to match(/\bdates\b|\bweek\b|\bseasontype\b|\bseason_type\b/)
  end
end
