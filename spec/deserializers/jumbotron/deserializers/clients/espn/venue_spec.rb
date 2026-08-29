# frozen_string_literal: true

RSpec.describe Jumbotron::Deserializers::Clients::Espn::Venue do
  describe ".call" do
    context "when the venue includes an address" do
      let(:payload) do
        {
          "id" => "1",
          "fullName" => "Lincoln Financial Field",
          "address" => { "city" => "Philadelphia", "state" => "PA", "country" => "USA" },
          "indoor" => false
        }
      end

      subject(:result) { described_class.call(payload) }

      it "maps city and state from address" do
        expect(result.address.city).to eq("Philadelphia")
        expect(result.address.state).to eq("PA")
      end
    end

    context "when address is omitted" do
      let(:payload) do
        {
          "id" => "2",
          "fullName" => "Unknown Venue"
        }
      end

      subject(:result) { described_class.call(payload) }

      it "leaves address nil" do
        expect(result.address).to be_nil
      end
    end
  end
end
