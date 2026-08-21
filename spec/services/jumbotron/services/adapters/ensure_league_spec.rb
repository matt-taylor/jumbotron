# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::EnsureLeague do
  let(:adapter) { Jumbotron::Adapters::Espn::Nfl }

  before { adapter.register! unless adapter.registered? }

  it "creates sport and league from adapter identity" do
    result = described_class.call(adapter: adapter)

    expect(result).to be_success
    expect(result.data[:league].name).to eq("nfl")
    expect(result.data[:league].sport.name).to eq("football")
  end

  it "reuses an existing case-insensitive league" do
    sport = create(:jumbotron_sport, name: "Football")
    league = create(:jumbotron_league, sport: sport, name: "NFL")

    result = described_class.call(adapter: adapter)

    expect(result).to be_success
    expect(result.data[:league].id).to eq(league.id)
    expect(Jumbotron::League.count).to eq(1)
  end
end
