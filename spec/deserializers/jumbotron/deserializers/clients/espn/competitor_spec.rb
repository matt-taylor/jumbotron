# frozen_string_literal: true

RSpec.describe Jumbotron::Deserializers::Clients::Espn::Competitor do
  describe ".call" do
    context "when the competitor includes records" do
      let(:payload) do
        {
          "id" => "1",
          "homeAway" => "home",
          "score" => "24",
          "team" => {
            "id" => "21",
            "displayName" => "Philadelphia Eagles",
            "abbreviation" => "PHI"
          },
          "records" => [
            { "name" => "overall", "type" => "total", "summary" => "1-0" },
            { "name" => "Home", "type" => "home", "summary" => "1-0" }
          ]
        }
      end

      subject(:result) { described_class.call(payload) }

      it "deserializes competitor records including total" do
        expect(result.records.map { |r| [r.type, r.summary] }).to include(
          %w[total 1-0],
          %w[home 1-0]
        )
      end
    end

    context "when records are omitted" do
      let(:payload) do
        {
          "id" => "1",
          "homeAway" => "away",
          "team" => {
            "id" => "6",
            "displayName" => "Dallas Cowboys",
            "abbreviation" => "DAL"
          }
        }
      end

      subject(:result) { described_class.call(payload) }

      it "leaves records nil" do
        expect(result.records).to be_nil
      end
    end
  end
end
