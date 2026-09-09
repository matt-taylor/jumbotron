# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Sandbox::NflHelpers::LineAcquisitionScope do
  let(:mapping) do
    create(
      :jumbotron_sandbox_game_mapping,
      home_spread: BigDecimal("-6.5"),
      total: BigDecimal("47.5")
    )
  end
  let(:game) { mapping.sandbox_game }

  before do
    create(
      :jumbotron_provider_identity,
      target: game,
      provider: "sandbox",
      object_namespace: "event",
      provider_id: "sandbox-event-1"
    )
  end

  subject(:scope) { described_class.call(game) }

  it "builds a line scope from the sandbox game identity" do
    expect(scope).to eq(
      endpoint: :competition_odds,
      acquisition: {
        event_id: "sandbox-event-1",
        competition_id: "sandbox-event-1",
        home_spread: "-6.5",
        total: "47.5"
      }
    )
  end
end
