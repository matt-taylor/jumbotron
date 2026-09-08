# frozen_string_literal: true

RSpec.describe Jumbotron::SandboxProjection do
  describe "registered identity" do
    subject(:projection) { create(:jumbotron_sandbox_projection) }

    it "persists distinct source and sandbox seasons" do
      expect(projection.source_season_id).not_to eq(projection.sandbox_season_id)
    end

    it "uses the sandbox adapter and NFL calendar zone" do
      expect(projection).to have_attributes(
        adapter_id: "sandbox_nfl",
        calendar_time_zone: "America/New_York"
      )
    end
  end

  describe "source consistency" do
    let(:source_season) { create(:jumbotron_season) }
    let(:other_phase) { create(:jumbotron_season_phase) }

    subject(:projection) do
      build(
        :jumbotron_sandbox_projection,
        source_season: source_season,
        source_anchor_phase: other_phase
      )
    end

    it "rejects an anchor phase from another season" do
      expect(projection).not_to be_valid
    end
  end
end
