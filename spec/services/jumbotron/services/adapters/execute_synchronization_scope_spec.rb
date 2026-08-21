# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ExecuteSynchronizationScope do
  let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
  let(:sport) { create(:jumbotron_sport, name: "football") }
  let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
  let(:acquisition) { { dates: 2025, season_type: 2, week: 4 } }
  let(:endpoint) { :scoreboard }

  before { adapter.register! unless adapter.registered? }

  def sync_success
    CommandTower::Workflows::WorkflowResult.success(payload: { games: [] }, http_status: :ok)
  end

  def sync_failure(code:, failure_class:)
    CommandTower::Workflows::WorkflowResult.failure(
      errors: [{ code: code, message: code }],
      http_status: :unprocessable_entity,
      meta: { failure_class: failure_class }
    )
  end

  def acquire_again
    Jumbotron::Synchronization::Lease.new.acquire(
      Jumbotron::Synchronization::Lease.scope(
        adapter_id: "espn_nfl",
        endpoint: endpoint,
        acquisition: acquisition
      )
    )
  end

  it "acquires the lease before invoking synchronization" do
    order = []
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call) do
      order << :sync
      sync_success
    end
    allow(Jumbotron::Synchronization::Lease).to receive(:new).and_wrap_original do |method, *args, **kwargs|
      lease = method.call(*args, **kwargs)
      allow(lease).to receive(:acquire).and_wrap_original do |acquire, scope|
        order << :acquire
        acquire.call(scope)
      end
      lease
    end

    result = described_class.call(
      adapter: adapter,
      league: league,
      endpoint: endpoint,
      acquisition: acquisition
    )

    expect(result).to be_success
    expect(result.data[:outcome]).to eq(:succeeded)
    expect(order).to eq(%i[acquire sync])
  end

  it "skips synchronization on lease contention" do
    held = Jumbotron::Synchronization::Lease.new.acquire(
      Jumbotron::Synchronization::Lease.scope(
        adapter_id: "espn_nfl",
        endpoint: endpoint,
        acquisition: acquisition
      )
    )
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call)

    result = described_class.call(
      adapter: adapter,
      league: league,
      endpoint: endpoint,
      acquisition: acquisition
    )

    expect(result.data[:outcome]).to eq(:contention)
    expect(Jumbotron::Workflows::SynchronizeAdapterWorkflow).not_to have_received(:call)
    Jumbotron::Synchronization::Lease.new.release(held.scope, token: held.token)
  end

  it "releases the lease after success" do
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(sync_success)

    described_class.call(
      adapter: adapter,
      league: league,
      endpoint: endpoint,
      acquisition: acquisition
    )

    expect(acquire_again).to be_acquired
  end

  it "releases the lease after an expected synchronization failure" do
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(
      sync_failure(code: "normalization_failed", failure_class: "normalization")
    )

    result = described_class.call(
      adapter: adapter,
      league: league,
      endpoint: endpoint,
      acquisition: acquisition
    )

    expect(result.data[:outcome]).to eq(:failed)
    expect(result.data[:failure_class]).to eq("normalization")
    expect(acquire_again).to be_acquired
  end

  it "releases the lease after an unexpected exception" do
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_raise("boom")

    expect do
      described_class.call(
        adapter: adapter,
        league: league,
        endpoint: endpoint,
        acquisition: acquisition
      )
    end.to raise_error("boom")

    expect(acquire_again).to be_acquired
  end

  it "maps provider cooldown from the nested workflow" do
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(
      sync_failure(code: "provider_cooldown_active", failure_class: "acquisition")
    )

    result = described_class.call(
      adapter: adapter,
      league: league,
      endpoint: endpoint,
      acquisition: acquisition
    )

    expect(result.data[:outcome]).to eq(:cooldown_active)
  end
end
