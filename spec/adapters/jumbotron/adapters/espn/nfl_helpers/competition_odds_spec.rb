# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Espn::NflHelpers::CompetitionOdds do
  describe ".call" do
    let(:observed_at) { Time.utc(2026, 8, 13, 12, 0, 0) }
    let(:fixture_relative) { "nfl/core_odds_pre_401873278.json" }
    let(:event_id) { "401873278" }
    let(:competition_id) { event_id }
    let(:payload) do
      JSON.parse(Jumbotron::Engine.root.join("spec/fixtures/espn", fixture_relative).read)
    end
    let(:odds) { Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::Get.call(payload) }

    subject(:ingest) do
      described_class.call(odds, observed_at:, event_id:, competition_id:)
    end

    context "when translating the NFL pre-game fixture" do
      let(:home_spread) do
        ingest.observations.find { |row| row.market == "spread" && row.outcome == "home" && row.source == "observed" }
      end
      let(:away_spread) do
        ingest.observations.find { |row| row.market == "spread" && row.outcome == "away" && row.source == "observed" }
      end
      let(:over) do
        ingest.observations.find { |row| row.market == "total" && row.outcome == "over" && row.source == "observed" }
      end
      let(:home_moneyline) do
        ingest.observations.find do |row|
          row.market == "moneyline" && row.outcome == "home" && row.source == "observed"
        end
      end

      it "returns a canonical ingest input" do
        expect(ingest).to be_a(Jumbotron::Canonical::LineIngestInput)
      end

      it "includes event and competition identities" do
        expect(ingest.game_identities.map(&:namespace)).to contain_exactly("event", "competition")
      end

      it "emits spread, total, and moneyline observations" do
        expect(ingest.observations.select { |row| row.source == "observed" }.map(&:market).uniq).to contain_exactly(
          "spread", "total", "moneyline"
        )
      end

      it "emits home, away, over, and under outcomes" do
        expect(ingest.observations.select { |row| row.source == "observed" }.map(&:outcome).uniq).to include(
          "home", "away", "over", "under"
        )
      end

      it "uses nested home point spread rather than a home-signed item spread" do
        expect(home_spread.line_value).to eq(BigDecimal("3.5"))
        expect(home_spread.line_value).not_to eq(BigDecimal("-3.5"))
        expect(home_spread.price_american).to eq(-102)
      end

      it "emits the away spread with the opposite sign" do
        expect(away_spread.line_value).to eq(BigDecimal("-3.5"))
        expect(away_spread.price_american).to eq(-118)
      end

      it "emits the total threshold and over price" do
        expect(over.line_value).to eq(BigDecimal("40.5"))
        expect(over.price_american).to eq(-108)
      end

      it "stores moneyline as price without a line value" do
        expect(home_moneyline.line_value).to be_nil
        expect(home_moneyline.price_american).to eq(160)
      end
    end

    context "when translating the NFL post-game fixture" do
      let(:fixture_relative) { "nfl/core_odds_post_401873272.json" }
      let(:event_id) { "401873272" }

      it "emits observed, provider_open, and provider_close provenance" do
        expect(ingest.observations.map(&:source).uniq).to include("observed", "provider_open", "provider_close")
      end

      it "emits typed observation inputs" do
        expect(ingest.observations).to all(be_a(Jumbotron::Canonical::LineObservationInput))
      end
    end

    context "when translating a multi-bookmaker in-play fixture" do
      let(:fixture_relative) { "nfl/core_odds_in_401874392.json" }
      let(:event_id) { "401874392" }

      it "preserves listed bookmakers independently" do
        expect(ingest.observations.map { |row| row.bookmaker_identity.id }.uniq).to contain_exactly("100", "200")
      end
    end

    context "when translating the soccer fixture" do
      let(:fixture_relative) { "soccer/eng1/core_odds_401879301.json" }
      let(:event_id) { "401879301" }
      let(:draw) do
        ingest.observations.find { |row| row.market == "moneyline" && row.outcome == "draw" }
      end
      let(:sparse_rows) do
        ingest.observations.select { |row| row.bookmaker_identity.id == "2000" }
      end

      it "emits a draw moneyline" do
        expect(draw).not_to be_nil
        expect(draw.price_american).to eq(650)
      end

      it "does not invent spread rows for the sparse bookmaker" do
        expect(sparse_rows.map(&:market).uniq).not_to include("spread")
      end

      it "does not fabricate zero line and price pairs" do
        expect(ingest.observations).to all(
          satisfy { |row| row.price_american != 0 || row.line_value != 0 }
        )
      end
    end
  end
end
