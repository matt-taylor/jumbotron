# frozen_string_literal: true

RSpec.describe Jumbotron::Synchronization::Lease do
  let(:store) { ActiveSupport::Cache::MemoryStore.new }
  let(:lease) { described_class.new(store: store, ttl: 2) }

  let(:scope) do
    described_class.scope(
      adapter_id: "espn_nfl",
      endpoint: :scoreboard,
      acquisition: { dates: 2026, season_type: 2, week: 4 }
    )
  end

  let(:other_scope) do
    described_class.scope(
      adapter_id: "espn_nfl",
      endpoint: :scoreboard,
      acquisition: { dates: 2026, season_type: 2, week: 5 }
    )
  end

  it "builds a stable opaque scope string" do
    expect(scope).to eq("espn_nfl:scoreboard:2026:2:4")
  end

  it "gives first owner the lease and contends on the same scope" do
    first = lease.acquire(scope)
    second = lease.acquire(scope)

    expect(first).to be_acquired
    expect(first.token).to be_present
    expect(second).not_to be_acquired
    expect(second.token).to be_nil
  end

  it "allows unrelated scopes independently" do
    expect(lease.acquire(scope)).to be_acquired
    expect(lease.acquire(other_scope)).to be_acquired
  end

  it "releases only for the owning token" do
    owned = lease.acquire(scope)
    expect(lease.release(scope, token: "stale-token")).to be(false)
    expect(lease.acquire(scope)).not_to be_acquired

    expect(lease.release(scope, token: owned.token)).to be(true)
    expect(lease.acquire(scope)).to be_acquired
  end

  it "expires abandoned leases after TTL" do
    expect(lease.acquire(scope)).to be_acquired
    sleep 2.1
    expect(lease.acquire(scope)).to be_acquired
  end

  it "rejects NullStore loudly" do
    expect do
      described_class.new(store: ActiveSupport::Cache::NullStore.new)
    end.to raise_error(Jumbotron::Synchronization::UnsupportedStoreError, /NullStore/)
  end
end
