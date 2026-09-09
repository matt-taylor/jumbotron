# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Sandbox::ResolveGameObservation do
  describe ".call" do
    let(:observed_at) { Time.utc(2026, 9, 13, 17, 0, 0) }
    let(:sport) { create(:jumbotron_sport, name: "football") }
    let(:league) { create(:jumbotron_league, sport: sport, name: "nfl-sandbox") }
    let(:season) { create(:jumbotron_season, league: league, name: "2026") }
    let(:game) do
      create(
        :jumbotron_game,
        league: league,
        season: season,
        scheduled_at: observed_at
      )
    end
    let(:home_score) { nil }
    let(:away_score) { nil }
    let(:home_participant) do
      create(:jumbotron_game_participant, game: game, role: "home", score: home_score)
    end
    let(:away_participant) do
      create(:jumbotron_game_participant, game: game, role: "away", score: away_score)
    end
    let(:line_values) do
      {
        %w[spread home] => BigDecimal("-3.5"),
        %w[total over] => BigDecimal("44.5")
      }
    end
    let(:bookmaker) { create(:jumbotron_bookmaker, name: "Sandbox Sportsbook") }

    before do
      create(
        :jumbotron_provider_identity,
        target: game,
        provider: "sandbox",
        object_namespace: "event",
        provider_id: "sandbox-event-1"
      )
      home_participant
      away_participant
      line_values.each do |(market, outcome), value|
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: bookmaker,
          market: market,
          outcome: outcome,
          source: "observed",
          line_value: value,
          observed_at: observed_at - 1.hour,
          changed_at: observed_at - 1.hour
        )
      end
      allow(SecureRandom).to receive(:random_number).and_return(0)
    end

    subject(:result) { described_class.call(game_id: game.id, observed_at: observed_at) }

    context "when the game has current spread and total lines" do
      it "selects and persists one plausible final" do
        expect(result).to be_success
        expect(result.data[:plan]).to have_attributes(
          game_id: game.id,
          home_score: 24,
          away_score: 21,
          selected_at: observed_at
        )
      end

      it "returns the observation at the requested time" do
        expect(result.data[:observation]).to have_attributes(
          lifecycle: "in_progress",
          home_score: 0,
          away_score: 0
        )
      end
    end

    context "when a plan was already selected" do
      before do
        create(
          :jumbotron_sandbox_game_plan,
          game: game,
          home_score: 35,
          away_score: 17,
          selected_at: observed_at - 1.day
        )
      end

      let(:line_values) { {} }

      it "reuses the persisted final without current lines" do
        expect(result.data[:plan]).to have_attributes(home_score: 35, away_score: 17)
      end
    end

    context "when resolution repeats with another random candidate available" do
      before do
        described_class.call(game_id: game.id, observed_at: observed_at)
        allow(SecureRandom).to receive(:random_number).and_return(1)
      end

      it "retains one persisted plan" do
        expect { result }.not_to change(Jumbotron::SandboxGamePlan, :count)
      end

      it "retains the first selected final" do
        expect(result.data[:plan]).to have_attributes(home_score: 24, away_score: 21)
      end
    end

    context "when a required consensus line is missing" do
      let(:line_values) do
        { %w[spread home] => BigDecimal("-3.5") }
      end

      it "fails with a structured unavailable-line error" do
        expect(result.errors.first.code).to eq("sandbox_outcome_line_unavailable")
      end
    end

    context "when the game belongs to the live provider world" do
      let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }

      it "fails with a structured invalid-game error" do
        expect(result.errors.first.code).to eq("invalid_sandbox_game")
      end
    end

    context "when a persisted score exceeds the selected final" do
      before do
        create(
          :jumbotron_sandbox_game_plan,
          game: game,
          home_score: 28,
          away_score: 20,
          selected_at: observed_at - 1.day
        )
      end

      let(:home_score) { 29 }
      let(:away_score) { 10 }
      let(:line_values) { {} }

      it "fails with a structured progression-state error" do
        expect(result.errors.first.code).to eq("invalid_sandbox_progression_state")
      end
    end
  end
end
