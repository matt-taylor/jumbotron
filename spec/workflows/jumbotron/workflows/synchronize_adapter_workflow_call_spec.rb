# frozen_string_literal: true

RSpec.describe Jumbotron::Workflows::SynchronizeAdapterWorkflow, ".call" do
  let(:scheduled_at) { Time.utc(2026, 9, 10, 17, 15, 0) }
  let(:observed_at) { scheduled_at - 2.days }
  let(:catalog) do
    sport = create(:jumbotron_sport, name: "football")
    source_league = create(:jumbotron_league, sport: sport, name: "nfl")
    sandbox_league = create(:jumbotron_league, sport: sport, name: "nfl-sandbox")
    source_season = create(:jumbotron_season, league: source_league, name: "2026")
    sandbox_season = create(:jumbotron_season, league: sandbox_league, name: "2026")
    sandbox_phase = create(:jumbotron_season_phase, season: sandbox_season, name: "regular_season")
    sandbox_group = create(
      :jumbotron_schedule_group,
      season: sandbox_season,
      season_phase: sandbox_phase,
      kind: "week",
      number: 1,
      name: "Week 1"
    )
    {
      source_league: source_league,
      sandbox_league: sandbox_league,
      source_season: source_season,
      sandbox_season: sandbox_season,
      sandbox_phase: sandbox_phase,
      sandbox_group: sandbox_group
    }
  end
  let(:source_game) do
    create(
      :jumbotron_game,
      league: catalog.fetch(:source_league),
      season: catalog.fetch(:source_season),
      scheduled_at: scheduled_at
    )
  end
  let(:sandbox_game) do
    create(
      :jumbotron_game,
      league: catalog.fetch(:sandbox_league),
      season: catalog.fetch(:sandbox_season),
      season_phase: catalog.fetch(:sandbox_phase),
      schedule_group: catalog.fetch(:sandbox_group),
      scheduled_at: scheduled_at
    )
  end
  let(:home_team) { create(:jumbotron_team, name: "Home Team") }
  let(:away_team) { create(:jumbotron_team, name: "Away Team") }
  let(:bookmaker) { create(:jumbotron_bookmaker, name: "Sandbox Sportsbook") }
  let!(:source_updated_at) { source_game.updated_at }
  let(:acquisition) { Jumbotron::Adapters::Sandbox::Nfl.acquisition_scope_for(sandbox_game).fetch(:acquisition) }

  before do
    Jumbotron::Adapters::Sandbox::Nfl.register! unless Jumbotron::Adapters::Sandbox::Nfl.registered?
    create(
      :jumbotron_provider_identity,
      target: source_game,
      provider: "espn",
      object_namespace: "event",
      provider_id: "espn-event-1"
    )
    create(
      :jumbotron_provider_identity,
      target: sandbox_game,
      provider: "sandbox",
      object_namespace: "event",
      provider_id: "sandbox-event-1"
    )
    create(
      :jumbotron_provider_identity,
      target: sandbox_game,
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
    create(:jumbotron_game_participant, game: sandbox_game, team: home_team, role: "home")
    create(:jumbotron_game_participant, game: sandbox_game, team: away_team, role: "away")
    create(
      :jumbotron_line_observation,
      game: sandbox_game,
      bookmaker: bookmaker,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-3.5"),
      observed_at: scheduled_at - 3.days,
      changed_at: scheduled_at - 3.days
    )
    create(
      :jumbotron_line_observation,
      game: sandbox_game,
      bookmaker: bookmaker,
      market: "total",
      outcome: "over",
      source: "observed",
      line_value: BigDecimal("44.5"),
      observed_at: scheduled_at - 3.days,
      changed_at: scheduled_at - 3.days
    )
    allow(SecureRandom).to receive(:random_number).and_return(0)
  end

  subject(:result) do
    described_class.call(
      adapter: Jumbotron::Adapters::Sandbox::Nfl,
      endpoint: :scoreboard,
      league_id: catalog.fetch(:sandbox_league).id,
      observed_at: observed_at,
      acquisition: acquisition
    )
  end

  it "applies a sandbox observation through the normal synchronization workflow" do
    expect(result).to be_success
    expect(result.payload[:games].size).to eq(1)
    expect(result.payload[:games].first).to have_attributes(
      league_id: catalog.fetch(:sandbox_league).id,
      lifecycle: "scheduled",
      observed_at: observed_at
    )
    expect(result.payload[:games].first.provider_identities.pluck(:provider)).to contain_exactly(
      "sandbox", "sandbox"
    )
  end

  it "reuses canonical teams without mutating the live source game" do
    expect(result).to be_success
    expect(result.payload[:games].first.teams).to contain_exactly(home_team, away_team)
    expect(source_game.reload.updated_at).to eq(source_updated_at)
    expect(source_game.provider_identities.pluck(:provider, :provider_id)).to eq(
      [%w[espn espn-event-1]]
    )
  end

  context "when the synthetic game reaches halftime" do
    let(:observed_at) { scheduled_at + 1.hour }

    it "persists an ordinary in-progress intermission" do
      expect(result.payload[:games].first).to have_attributes(
        lifecycle: "in_progress",
        progress_state: "intermission",
        progress_segment_kind: "quarter",
        progress_segment_number: 2,
        progress_clock_seconds: nil
      )
    end
  end

  context "when the synthetic game reaches two hours" do
    let(:observed_at) { scheduled_at + 2.hours }

    it "persists the exact selected final" do
      expect(result.payload[:games].first.game_participants)
        .to contain_exactly(
          have_attributes(role: "home", score: 24, result: "win"),
          have_attributes(role: "away", score: 21, result: "loss")
        )
    end

    it "persists a terminal lifecycle without progress" do
      expect(result.payload[:games].first).to have_attributes(
        lifecycle: "completed",
        progress_state: nil,
        progress_segment_kind: nil,
        progress_segment_number: nil
      )
    end
  end

  context "when a later poll carries an earlier wall clock" do
    before do
      described_class.call(
        adapter: Jumbotron::Adapters::Sandbox::Nfl,
        endpoint: :scoreboard,
        league_id: catalog.fetch(:sandbox_league).id,
        observed_at: scheduled_at + 70.minutes,
        acquisition: acquisition
      )
    end

    let(:observed_at) { scheduled_at + 10.minutes }

    it "accepts the clamped observation" do
      expect(result.errors).to be_empty
    end

    it "does not rewind the persisted quarter" do
      expect(result.payload[:games].first).to have_attributes(
        lifecycle: "in_progress",
        progress_state: "active",
        progress_segment_number: 3
      )
    end

    it "does not decrease persisted scores" do
      expect(result.payload[:games].first.game_participants)
        .to contain_exactly(
          have_attributes(role: "home", score: 13),
          have_attributes(role: "away", score: 11)
        )
    end
  end
end
