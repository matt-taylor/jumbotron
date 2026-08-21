# frozen_string_literal: true

RSpec.describe Jumbotron::Workflows::ExecuteLineUpdatePolicyWorkflow do
  include ActiveSupport::Testing::TimeHelpers

  describe "#call" do
    let(:now) { Time.utc(2026, 8, 13, 18, 0, 0) }
    let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
    let(:sport) { create(:jumbotron_sport, name: "football") }
    let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
    let(:season) { create(:jumbotron_season, league: league, name: "2025") }

    before do
      adapter.register! unless adapter.registered?
      league
    end

    around { |example| travel_to(now) { example.run } }

    context "when no games are eligible" do
      subject(:result) { described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming_lines") }

      it "succeeds with empty work" do
        expect(result).to be_success
        expect(result.payload[:eligible_games]).to eq(0)
        expect(result.payload[:unique_scopes]).to eq(0)
      end
    end

    context "when a game update policy id is supplied" do
      subject(:result) { described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming") }

      it "fails isolation" do
        expect(result).to be_failure
        expect(result.errors.first[:code]).to eq("invalid_policy_type")
      end
    end

    context "when an upcoming game has provider identities" do
      let(:game) do
        create(
          :jumbotron_game,
          league: league,
          season: season,
          scheduled_at: now + 1.week,
          lifecycle: "scheduled"
        )
      end

      before do
        create(
          :jumbotron_provider_identity,
          target: game, provider: "espn", object_namespace: "event", provider_id: "401873278"
        )
        create(
          :jumbotron_provider_identity,
          target: game, provider: "espn", object_namespace: "competition", provider_id: "401873278"
        )
        allow(Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.success(data: { outcome: :succeeded })
        )
      end

      subject(:result) { described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming_lines") }

      it "executes one unique scope" do
        expect(result).to be_success
        expect(result.payload[:eligible_games]).to eq(1)
        expect(result.payload[:unique_scopes]).to eq(1)
        expect(result.payload[:succeeded_scopes]).to eq(1)
        expect(Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope).to have_received(:call)
      end
    end

    context "when cooldown is active before any scope" do
      let(:game) do
        create(
          :jumbotron_game,
          league: league,
          season: season,
          scheduled_at: now + 1.week,
          lifecycle: "scheduled"
        )
      end

      before do
        create(
          :jumbotron_provider_identity,
          target: game, provider: "espn", object_namespace: "event", provider_id: "401873278"
        )
        create(
          :jumbotron_provider_identity,
          target: game, provider: "espn", object_namespace: "competition", provider_id: "401873278"
        )
        allow(adapter).to receive(:provider_cooling_down?).and_return(true)
        allow(Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope).to receive(:call)
      end

      subject(:result) { described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming_lines") }

      it "skips remaining scopes" do
        expect(result).to be_success
        expect(result.payload[:skipped_cooldown]).to eq(1)
        expect(Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope).not_to have_received(:call)
      end
    end
  end
end
