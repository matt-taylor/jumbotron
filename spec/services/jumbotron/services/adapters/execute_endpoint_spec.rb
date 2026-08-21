# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ExecuteEndpoint do
  after { Jumbotron::Clients.reset_providers! }

  let(:fixture_root) { Jumbotron::Engine.root.join("spec/fixtures/espn/nfl") }
  let(:observed_at) { Time.utc(2026, 8, 12, 12, 0, 0) }

  before { Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered? }

  it "returns SyncInput from a successful teams acquire/transform" do
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(
        status: 200,
        body: fixture_root.join("teams.json").read,
        duration_ms: 1
      )
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))

    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :teams,
      observed_at: observed_at
    )

    expect(result).to be_success
    expect(result.data[:sync_input]).to be_a(Jumbotron::Canonical::SyncInput)
    expect(result.data[:sync_input].teams).not_to be_empty
  end

  it "maps acquisition failure to AcquisitionFailedError" do
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(
        status: 500,
        body: '{"message":"boom"}',
        duration_ms: 1
      )
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))

    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      observed_at: observed_at
    )

    expect(result).to be_failure
    expect(result.errors.first.code).to eq("acquisition_failed")
  end
end
