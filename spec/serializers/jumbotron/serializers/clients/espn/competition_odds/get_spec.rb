# frozen_string_literal: true

RSpec.describe Jumbotron::Serializers::Clients::Espn::CompetitionOdds::Get do
  def input(sport:, league:, event_id:, competition_id:)
    Jumbotron::Clients::Espn::CompetitionOdds::GetInput.new(
      sport: sport,
      league: league,
      event_id: event_id,
      competition_id: competition_id
    )
  end

  it "returns a SerializedRequest" do
    serialized = described_class.call(
      input(sport: "soccer", league: "eng.1", event_id: "1", competition_id: "1")
    )

    expect(serialized).to be_a(CommandTower::Clients::SerializedRequest)
  end

  it "emits an empty query" do
    serialized = described_class.call(
      input(sport: "soccer", league: "eng.1", event_id: "1", competition_id: "1")
    )

    expect(serialized.query).to eq({})
  end
end
