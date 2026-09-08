# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Sandbox::NflHelpers::AcquisitionScope do
  let(:sport) { create(:jumbotron_sport, name: "football") }
  let(:league) { create(:jumbotron_league, sport: sport, name: "nfl-sandbox") }
  let(:season) { create(:jumbotron_season, league: league, name: "2026") }
  let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }
  let(:group) do
    create(
      :jumbotron_schedule_group,
      season: season,
      season_phase: phase,
      kind: "week",
      number: 1,
      name: "Week 1"
    )
  end
  let(:game) do
    create(
      :jumbotron_game,
      league: league,
      season: season,
      season_phase: phase,
      schedule_group: group,
      scheduled_at: Time.utc(2026, 9, 10, 17, 15)
    )
  end
  let(:home_team) { create(:jumbotron_team, name: "Home Team") }
  let(:away_team) { create(:jumbotron_team, name: "Away Team") }

  before do
    create(
      :jumbotron_provider_identity,
      target: game,
      provider: "sandbox",
      object_namespace: "event",
      provider_id: "sandbox-event-1"
    )
    create(
      :jumbotron_provider_identity,
      target: game,
      provider: "sandbox",
      object_namespace: "competition",
      provider_id: "sandbox-competition-1"
    )
    create(
      :jumbotron_provider_identity,
      target: home_team,
      provider: "espn",
      object_namespace: "team",
      provider_id: "10"
    )
    create(
      :jumbotron_provider_identity,
      target: away_team,
      provider: "espn",
      object_namespace: "team",
      provider_id: "20"
    )
    create(:jumbotron_game_participant, game: game, team: home_team, role: "home")
    create(:jumbotron_game_participant, game: game, team: away_team, role: "away")
  end

  subject(:scope) { described_class.call(game) }

  it "builds an in-process sandbox observation scope" do
    expect(scope[:endpoint]).to eq(:scoreboard)
    expect(scope[:acquisition]).to include(
      game_id: game.id,
      event_id: "sandbox-event-1",
      competition_id: "sandbox-competition-1",
      season_year: 2026,
      season_phase_key: "regular_season",
      week_number: 1
    )
    expect(scope[:acquisition].dig(:home, :provider_id)).to eq("10")
    expect(scope[:acquisition].dig(:away, :provider_id)).to eq("20")
  end
end
