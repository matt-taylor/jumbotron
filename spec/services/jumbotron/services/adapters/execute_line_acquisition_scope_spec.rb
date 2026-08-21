# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope do
  describe ".call" do
    let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
    let(:game) { create(:jumbotron_game) }
    let(:event_id) { "401874392" }
    let(:acquisition) { { event_id: event_id, competition_id: event_id } }
    let(:odds_body) do
      Jumbotron::Engine.root.join("spec/fixtures/espn/nfl/core_odds_in_401874392.json").read
    end
    let(:transport) do
      Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(status: 200, body: odds_body, duration_ms: 1)
      end
    end

    before do
      adapter.register! unless adapter.registered?
      Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))
      create(
        :jumbotron_provider_identity,
        target: game, provider: "espn", object_namespace: "event", provider_id: event_id
      )
      create(
        :jumbotron_provider_identity,
        target: game, provider: "espn", object_namespace: "competition", provider_id: event_id
      )
    end

    after { Jumbotron::Clients.reset_providers! }

    context "when ESPN returns odds and the game is mapped" do
      subject(:result) { described_class.call(adapter: adapter, acquisition: acquisition) }

      it "persists observations and reports success" do
        expect(result).to be_success
        expect(result.data[:outcome]).to eq(:succeeded)
        expect(Jumbotron::LineObservation.where(game: game).count).to be > 0
      end
    end

    context "when a lease is already held" do
      let(:held) do
        Jumbotron::Synchronization::Lease.new.acquire(
          Jumbotron::Synchronization::Lease.scope(
            adapter_id: "espn_nfl",
            endpoint: :competition_odds,
            acquisition: acquisition
          )
        )
      end

      before { held }
      after { Jumbotron::Synchronization::Lease.new.release(held.scope, token: held.token) }

      subject(:result) { described_class.call(adapter: adapter, acquisition: acquisition) }

      it "skips acquisition" do
        expect(result.data[:outcome]).to eq(:contention)
        expect(Jumbotron::LineObservation.count).to eq(0)
      end
    end

    context "when ESPN cooldown is active" do
      before { allow(adapter).to receive(:provider_cooling_down?).and_return(true) }

      subject(:result) { described_class.call(adapter: adapter, acquisition: acquisition) }

      it "skips acquisition" do
        expect(result.data[:outcome]).to eq(:cooldown_active)
        expect(Jumbotron::LineObservation.count).to eq(0)
      end
    end

    context "when provider acquisition fails" do
      let(:transport) do
        Jumbotron::SpecSupport::FakeTransport.new do |_request|
          CommandTower::Clients::Transport::Response.build(status: 500, body: "{}", duration_ms: 1)
        end
      end

      subject(:result) { described_class.call(adapter: adapter, acquisition: acquisition) }

      it "releases the lease" do
        expect(result.data[:outcome]).to eq(:failed)
        retry_hold = Jumbotron::Synchronization::Lease.new.acquire(
          Jumbotron::Synchronization::Lease.scope(
            adapter_id: "espn_nfl",
            endpoint: :competition_odds,
            acquisition: acquisition
          )
        )
        expect(retry_hold).to be_acquired
      end
    end
  end
end
