# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Sandbox::NflHelpers::OutcomeCandidates do
  describe ".call" do
    subject(:candidates) { described_class.call(home_spread: home_spread, total: total) }

    context "with a typical home-favorite line" do
      let(:home_spread) { BigDecimal("-3.5") }
      let(:total) { BigDecimal("44.5") }

      it "returns a small set of distinct non-tied finals" do
        expect(candidates.length).to be_between(3, 5)
        expect(candidates).to eq(candidates.uniq)
        expect(candidates).to all(satisfy { |candidate| candidate.home_score != candidate.away_score })
      end

      it "keeps candidate totals near the known total" do
        expect(candidates.map { |candidate| candidate.home_score + candidate.away_score })
          .to all(be_between(41, 48))
      end

      it "centers candidate margins near the known spread" do
        expect(candidates.map { |candidate| candidate.home_score - candidate.away_score })
          .to all(be_between(0, 7))
      end
    end

    context "with invalid line values" do
      let(:home_spread) { "not-a-spread" }
      let(:total) { "not-a-total" }

      it "returns no candidates" do
        expect(candidates).to be_empty
      end
    end
  end
end
