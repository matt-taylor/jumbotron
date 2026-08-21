# frozen_string_literal: true

RSpec.describe Jumbotron::LineObservation do
  describe ".create" do
    context "when required associations and identities are present" do
      subject(:observation) { create(:jumbotron_line_observation) }

      it "persists" do
        expect(observation).to be_persisted
      end

      it "belongs to a game" do
        expect(observation.game).to be_a(Jumbotron::Game)
      end

      it "belongs to a bookmaker" do
        expect(observation.bookmaker).to be_a(Jumbotron::Bookmaker)
      end

      it "belongs to an observation batch" do
        expect(observation.observation_batch).to be_a(Jumbotron::ObservationBatch)
      end
    end
  end

  describe "invariants" do
    context "when market is unknown" do
      subject(:observation) { build(:jumbotron_line_observation, market: "prop") }

      it "is invalid" do
        expect(observation).not_to be_valid
      end
    end

    context "when outcome is unknown" do
      subject(:observation) { build(:jumbotron_line_observation, outcome: "push") }

      it "is invalid" do
        expect(observation).not_to be_valid
      end
    end

    context "when source is unknown" do
      subject(:observation) { build(:jumbotron_line_observation, source: "poll") }

      it "is invalid" do
        expect(observation).not_to be_valid
      end
    end
  end
end
