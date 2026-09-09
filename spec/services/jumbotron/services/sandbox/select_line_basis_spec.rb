# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Sandbox::SelectLineBasis do
  describe ".call" do
    let(:source_spread) { nil }
    let(:source_total) { nil }
    let(:params) do
      {
        source_game_id: 17,
        reset_fingerprint: "reset-v1",
        source_spread: source_spread,
        source_total: source_total
      }
    end

    subject(:result) { described_class.call(**params) }

    context "with usable source consensus" do
      let(:source_spread) { BigDecimal("-3.7") }
      let(:source_total) { BigDecimal("44.8") }

      it "normalizes the pair to half points" do
        expect(result.data).to include(
          home_spread: BigDecimal("-3.5"),
          total: BigDecimal("45.0"),
          line_source: "source_consensus"
        )
      end
    end

    context "without usable source consensus" do
      it "returns a stable plausible fallback" do
        repeated = described_class.call(**params)
        home_score = (result.data[:total] - result.data[:home_spread]) / 2
        away_score = (result.data[:total] + result.data[:home_spread]) / 2

        expect(repeated.data).to eq(result.data)
        expect(result.data[:home_spread].abs).to be_between(BigDecimal("0.5"), BigDecimal("10.5"))
        expect(result.data[:total]).to be_between(BigDecimal("37.5"), BigDecimal("54.5"))
        expect(home_score).to be_between(10, 38)
        expect(away_score).to be_between(10, 38)
      end
    end
  end
end
