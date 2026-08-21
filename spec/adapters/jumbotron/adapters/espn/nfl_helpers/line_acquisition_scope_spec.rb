# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Espn::NflHelpers::LineAcquisitionScope do
  describe ".call" do
    let(:game) { create(:jumbotron_game) }

    context "when event and competition identities are present" do
      before do
        create(
          :jumbotron_provider_identity,
          target: game, provider: "espn", object_namespace: "event", provider_id: "401873278"
        )
        create(
          :jumbotron_provider_identity,
          target: game, provider: "espn", object_namespace: "competition", provider_id: "401873279"
        )
        game.reload
      end

      subject(:scope) { described_class.call(game) }

      it "returns an opaque competition odds acquisition" do
        expect(scope[:endpoint]).to eq(:competition_odds)
        expect(scope[:acquisition]).to eq(event_id: "401873278", competition_id: "401873279")
      end
    end

    context "when identities are missing" do
      subject(:scope) { described_class.call(game) }

      it "returns nil" do
        expect(scope).to be_nil
      end
    end
  end
end
