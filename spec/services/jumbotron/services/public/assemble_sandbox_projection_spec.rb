# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Public::AssembleSandboxProjection do
  describe ".call" do
    let(:sport) { create(:jumbotron_sport, name: "football") }
    let(:league) { create(:jumbotron_league, sport:, name: "nfl") }
    let(:source_season) { create(:jumbotron_season, league:, name: "2026") }
    let(:source_anchor_phase) do
      create(:jumbotron_season_phase, season: source_season, name: "regular_season")
    end
    let(:projection) do
      create(
        :jumbotron_sandbox_projection,
        name: "apple-review",
        source_season:,
        source_anchor_phase:
      )
    end

    subject(:result) { described_class.call(projection:) }

    it "returns an immutable public projection with Jumbotron-authored source identity" do
      expect(result).to be_success
      expect(result.data[:public_projection]).to be_a(Jumbotron::Public::SandboxProjection)
      expect(result.data[:public_projection].source_label).to eq("NFL 2026 Regular Season")
      expect(result.data[:public_projection]).not_to be_a(ActiveRecord::Base)
      expect(result.data[:public_projection].source).not_to be_a(ActiveRecord::Base)
    end
  end
end
