# frozen_string_literal: true

RSpec.describe Jumbotron::SandboxGameMapping do
  describe "source and target identity" do
    subject(:mapping) { create(:jumbotron_sandbox_game_mapping) }

    it "persists one source-to-sandbox mapping with a line basis" do
      expect(mapping).to have_attributes(
        home_spread: BigDecimal("-3.5"),
        total: BigDecimal("44.5"),
        line_fingerprint: "line-v1"
      )
    end

    it "uses a live source and sandbox target" do
      expect(mapping.source_game.league.name).not_to eq(mapping.sandbox_game.league.name)
    end
  end

  describe "provider-world validation" do
    let(:projection) { create(:jumbotron_sandbox_projection) }
    let(:sandbox_game) do
      create(
        :jumbotron_game,
        league: projection.sandbox_season.league,
        season: projection.sandbox_season
      )
    end

    subject(:mapping) do
      build(
        :jumbotron_sandbox_game_mapping,
        sandbox_projection: projection,
        source_game: sandbox_game,
        sandbox_game: sandbox_game
      )
    end

    it "rejects a sandbox game as the source" do
      expect(mapping).not_to be_valid
    end
  end
end
