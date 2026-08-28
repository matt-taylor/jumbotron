# frozen_string_literal: true

RSpec.describe Jumbotron::Deserializers::Clients::Espn::Team do
  describe ".call" do
    context "when the payload includes nickname" do
      let(:payload) do
        {
          "id" => "28",
          "displayName" => "Washington Commanders",
          "name" => "Commanders",
          "nickname" => "Commanders",
          "shortDisplayName" => "Commanders",
          "location" => "Washington",
          "abbreviation" => "WSH"
        }
      end

      subject(:result) { described_class.call(payload) }

      it "maps nickname from the ESPN field" do
        expect(result.nickname).to eq("Commanders")
        expect(result.display_name).to eq("Washington Commanders")
      end
    end

    context "when the payload omits nickname" do
      let(:payload) do
        {
          "id" => "21",
          "displayName" => "Philadelphia Eagles",
          "name" => "Eagles",
          "shortDisplayName" => "Eagles",
          "location" => "Philadelphia",
          "abbreviation" => "PHI"
        }
      end

      subject(:result) { described_class.call(payload) }

      it "leaves nickname nil" do
        expect(result.nickname).to be_nil
        expect(result.name).to eq("Eagles")
      end
    end
  end
end
