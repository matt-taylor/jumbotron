# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Operation do
  after { Jumbotron::Clients.reset_providers! }

  let(:fixture_root) { Jumbotron::Engine.root.join("spec/fixtures/espn/nfl") }
  let(:observed_at) { Time.utc(2026, 8, 12, 12, 0, 0) }

  it "acquires then transforms through the declared resource/transformer pair" do
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(
        status: 200,
        body: fixture_root.join("teams.json").read,
        duration_ms: 1
      )
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))

    operation = Jumbotron::Adapters::Espn::Nfl.operation(:teams)
    result = operation.acquire
    expect(result).to be_success

    input = operation.transform(result.output, observed_at: observed_at)
    expect(input).to be_a(Jumbotron::Canonical::SyncInput)
    expect(input.teams).not_to be_empty
  end
end
