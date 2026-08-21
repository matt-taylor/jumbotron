# frozen_string_literal: true

RSpec.describe Jumbotron::Providers::Espn::Cooldown do
  let(:store) { ActiveSupport::Cache::MemoryStore.new }
  let(:now) { Time.utc(2026, 8, 13, 12, 0, 0) }
  let(:clock) { -> { now } }
  let(:cooldown) { described_class.new(store: store, clock: clock) }

  def upstream_5xx
    CommandTower::Clients::Errors::UpstreamError.new(
      message: "server",
      details: { status: 503 }
    )
  end

  def upstream_transport
    CommandTower::Clients::Errors::UpstreamError.new(
      message: "timeout",
      cause: CommandTower::Clients::Transport::Error.new("timed out")
    )
  end

  it "starts at 5s and doubles until the 180s cap" do
    expect(described_class.delay_for(1)).to eq(5)
    expect(described_class.delay_for(2)).to eq(10)
    expect(described_class.delay_for(3)).to eq(20)
    expect(described_class.delay_for(4)).to eq(40)
    expect(described_class.delay_for(5)).to eq(80)
    expect(described_class.delay_for(6)).to eq(160)
    expect(described_class.delay_for(7)).to eq(180)
    expect(described_class.delay_for(8)).to eq(180)
  end

  it "records provider failures, cools down, and resets on success" do
    expect(cooldown.record_failure!(upstream_5xx, now: now)).to be(true)
    expect(cooldown.failure_count).to eq(1)
    expect(cooldown.cooling_down?(now: now)).to be(true)
    expect(cooldown.retry_after(now: now)).to eq(5)
    expect(cooldown.cooling_down?(now: now + 5)).to be(false)

    cooldown.record_failure!(upstream_transport, now: now + 5)
    expect(cooldown.failure_count).to eq(2)
    expect(cooldown.retry_after(now: now + 5)).to eq(10)

    cooldown.record_success!
    expect(cooldown.failure_count).to eq(0)
    expect(cooldown.cooling_down?(now: now + 5)).to be(false)
  end

  it "shares provider-wide state and ignores non-provider failures" do
    other = described_class.new(store: store, clock: clock)
    cooldown.record_failure!(upstream_5xx, now: now)
    expect(other.failure_count).to eq(1)

    expect(
      cooldown.record_failure!(
        Jumbotron::Adapters::TransformError.new("transform"),
        now: now
      )
    ).to be(false)
    expect(cooldown.failure_count).to eq(1)
  end
end
