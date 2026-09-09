# frozen_string_literal: true

RSpec.describe Jumbotron::Deserializers::Public::RegisterSandboxProjection do
  describe ".call" do
    let(:params) do
      {
        name: "apple-review",
        source: {
          sport: "football",
          league: "nfl",
          season: "2026",
          season_phase: "regular_season"
        }
      }
    end

    subject(:result) { described_class.call(params) }

    context "with a complete registration" do
      it "returns an immutable public request" do
        expect(result.input).to be_a(Jumbotron::Public::RegisterSandboxProjectionRequest)
      end
    end

    context "when source is not structured" do
      let(:params) { { name: "apple-review", source: "nfl" } }

      it "fails validation" do
        expect(result).to be_failure
      end
    end
  end
end
