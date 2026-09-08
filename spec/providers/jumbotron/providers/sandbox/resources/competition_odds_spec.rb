# frozen_string_literal: true

RSpec.describe Jumbotron::Providers::Sandbox::Resources::CompetitionOdds do
  let(:query) { { event_id: "sandbox-event-1", competition_id: "sandbox-competition-1" } }

  subject(:result) do
    described_class.acquire(adapter: Jumbotron::Adapters::Sandbox::Nfl, **query)
  end

  it "returns the in-process observation without external I/O" do
    expect(result).to be_success
    expect(result.output).to eq(query)
  end
end
