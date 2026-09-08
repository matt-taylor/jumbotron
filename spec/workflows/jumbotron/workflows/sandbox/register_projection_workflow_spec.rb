# frozen_string_literal: true

RSpec.describe Jumbotron::Workflows::Sandbox::RegisterProjectionWorkflow do
  describe ".call" do
    let(:sport) { create(:jumbotron_sport, name: "football") }
    let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
    let(:season) { create(:jumbotron_season, league: league, name: "2026") }
    let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }
    let(:params) do
      {
        name: "apple-review",
        source: {
          sport: sport.name,
          league: league.name,
          season: season.name,
          season_phase: phase.name
        }
      }
    end

    before do
      phase
    end

    subject(:result) { described_class.call(**params) }

    context "with a new named sandbox" do
      it "registers a Jumbotron-owned projection" do
        expect(result).to be_success
        expect(result.payload[:sandbox_projection]).to be_a(Jumbotron::Public::SandboxProjection)
        expect(Jumbotron::SandboxProjection.find_by!(name: "apple-review")).to have_attributes(
          source_season_id: season.id,
          adapter_id: "sandbox_nfl"
        )
      end

      it "is idempotent for the same source" do
        expect { 2.times { described_class.call(**params) } }.to change(Jumbotron::SandboxProjection, :count).by(1)
      end
    end

    context "when the name is registered to another source" do
      let(:other_season) { create(:jumbotron_season, league: league, name: "2025") }
      let(:other_phase) do
        create(:jumbotron_season_phase, season: other_season, name: "regular_season")
      end

      before do
        create(
          :jumbotron_sandbox_projection,
          name: "apple-review",
          source_season: other_season,
          source_anchor_phase: other_phase
        )
      end

      it "returns a stable conflict error" do
        expect(result.errors.first[:code]).to eq("sandbox_projection_conflict")
      end
    end
  end
end
