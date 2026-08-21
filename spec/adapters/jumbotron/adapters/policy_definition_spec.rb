# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::PolicyDefinition do
  describe "contract" do
    it "requires id and type; cadence may be nil" do
      definition = described_class.new(
        id: :far_future,
        type: :future_game_update,
        cadence: nil,
        eligible: ->(_game, now:) { now }
      )

      expect(definition.id).to eq(:far_future)
      expect(definition.type).to eq(:future_game_update)
      expect(definition.cadence).to be_nil
    end

    it "delegates eligible? to the callable" do
      game = instance_double(Jumbotron::Game, lifecycle: "scheduled")
      definition = described_class.new(
        id: :live,
        type: :live_game_update,
        cadence: Jumbotron::Adapters::Cadence.new(every: 5, unit: :minute),
        eligible: ->(g, now:) { g.lifecycle == "scheduled" && now }
      )

      expect(definition.eligible?(game, now: true)).to be(true)
    end
  end
end
