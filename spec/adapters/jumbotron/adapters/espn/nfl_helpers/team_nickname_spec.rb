# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Espn::NflHelpers::TeamNickname do
  describe ".resolve" do
    context "when nickname is present" do
      let(:team) do
        instance_double(
          Jumbotron::Deserializers::Clients::Espn::Team::Result,
          nickname: "Commanders",
          name: "Commanders",
          short_display_name: "Commanders"
        )
      end

      subject(:resolved) { described_class.resolve(team) }

      it "prefers nickname" do
        expect(resolved).to eq("Commanders")
      end
    end

    context "when nickname is blank and name is present" do
      let(:team) do
        instance_double(
          Jumbotron::Deserializers::Clients::Espn::Team::Result,
          nickname: nil,
          name: "Eagles",
          short_display_name: "Eagles"
        )
      end

      subject(:resolved) { described_class.resolve(team) }

      it "uses name" do
        expect(resolved).to eq("Eagles")
      end
    end

    context "when only short_display_name is present" do
      let(:team) do
        instance_double(
          Jumbotron::Deserializers::Clients::Espn::Team::Result,
          nickname: nil,
          name: nil,
          short_display_name: "49ers"
        )
      end

      subject(:resolved) { described_class.resolve(team) }

      it "uses short_display_name" do
        expect(resolved).to eq("49ers")
      end
    end
  end
end
