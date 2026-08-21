# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Espn::NflHelpers::AcquisitionScope do
  it "translates canonical grouping into an ESPN scoreboard acquisition" do
    season = create(:jumbotron_season, name: "2025")
    phase = create(:jumbotron_season_phase, season: season, name: "regular_season")
    group = create(
      :jumbotron_schedule_group,
      season: season,
      season_phase: phase,
      kind: "week",
      number: 4,
      name: "Week 4"
    )
    game = create(
      :jumbotron_game,
      league: season.league,
      season: season,
      season_phase: phase,
      schedule_group: group
    )

    expect(described_class.call(game)).to eq(
      endpoint: :scoreboard,
      acquisition: { dates: 2025, season_type: 2, week: 4 }
    )
  end

  it "returns nil when grouping is incomplete" do
    game = create(:jumbotron_game, schedule_group: nil)

    expect(described_class.call(game)).to be_nil
  end
end
