# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope, ".call" do
  let(:game) { create(:jumbotron_game) }
  let(:acquisition) do
    {
      event_id: "sandbox-event-1",
      competition_id: "sandbox-competition-1",
      home_spread: "-3.5",
      total: "44.5"
    }
  end

  before do
    create(
      :jumbotron_provider_identity,
      target: game,
      provider: "sandbox",
      object_namespace: "event",
      provider_id: "sandbox-event-1"
    )
    create(
      :jumbotron_provider_identity,
      target: game,
      provider: "sandbox",
      object_namespace: "competition",
      provider_id: "sandbox-competition-1"
    )
  end

  subject(:result) do
    described_class.call(
      adapter: Jumbotron::Adapters::Sandbox::Nfl,
      acquisition: acquisition
    )
  end

  it "persists synthetic observations through the normal line service" do
    expect(result).to be_success
    expect(result.data[:outcome]).to eq(:succeeded)
    expect(game.line_observations.count).to eq(4)
    expect(game.line_observations.pluck(:source).uniq).to eq(["observed"])
    expect(game.line_observations.joins(:bookmaker).pluck("jumbotron_bookmakers.name").uniq).to eq(
      ["Sandbox Sportsbook"]
    )
  end
end
