# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Sandbox::NflHelpers::CompetitionOdds do
  let(:observed_at) { Time.utc(2026, 9, 8, 16, 0, 0) }
  let(:payload) { { event_id: "sandbox-event-1", competition_id: "sandbox-competition-1" } }
  let(:acquisition) { payload.merge(home_spread: "-6.5", total: "47.5") }

  subject(:ingest) do
    described_class.call(payload, observed_at: observed_at, acquisition: acquisition)
  end

  it "builds consensus-eligible observed lines for a sandbox game" do
    expect(ingest).to be_a(Jumbotron::Canonical::LineIngestInput)
    expect(ingest.provider).to eq("sandbox")
    expect(ingest.adapter_scope).to eq("sandbox_nfl")
    expect(ingest.game_identities.map(&:provider)).to contain_exactly("sandbox", "sandbox")
    expect(ingest.observations.map(&:source).uniq).to eq(["observed"])
    expect(ingest.observations.map(&:market).uniq).to contain_exactly("spread", "total")
    expect(ingest.observations.map(&:bookmaker_name).uniq).to eq(["Sandbox Sportsbook"])
    expect(ingest.observations.map(&:line_value)).to contain_exactly(
      BigDecimal("-6.5"),
      BigDecimal("6.5"),
      BigDecimal("47.5"),
      BigDecimal("47.5")
    )
  end
end
