# frozen_string_literal: true

RSpec.describe Jumbotron::Workflows::ExecuteDiscoveryWorkflow do
  include ActiveSupport::Testing::TimeHelpers

  let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
  let(:now) { Time.utc(2026, 8, 13, 19, 0, 0) }
  let(:job) { Jumbotron::DiscoveryJob.new }

  before do
    adapter.register! unless adapter.registered?
    allow(adapter).to receive_messages(
      scopes_for_discovery: CommandTower::Clients::ClientResult.success(
        output: [{ dates: 2026, season_type: 2, week: 1 }]
      ),
      provider_cooling_down?: false,
      provider_retry_after: 180
    )
  end

  around { |example| travel_to(now) { example.run } }

  def scope_success
    CommandTower::Services::ServiceResult.success(data: { outcome: :succeeded })
  end

  def scope_outcome(outcome, failure_class: nil)
    CommandTower::Services::ServiceResult.success(
      data: { outcome: outcome, failure_class: failure_class }
    )
  end

  def continue_from_job(attempt: 1)
    described_class.call_from_job(
      job: job,
      continuation_attempt: attempt,
      adapter_id: "espn_nfl",
      discovery_id: "full_season"
    )
  end

  it "succeeds when every expanded week scope succeeds and does not continue" do
    allow(Jumbotron::Services::Adapters::ExecuteSynchronizationScope).to receive(:call).and_return(scope_success)

    result = described_class.call(adapter_id: "espn_nfl", discovery_id: "full_season")

    expect(result).to be_success
    expect(result.payload[:adapter_id]).to eq("espn_nfl")
    expect(result.payload[:discovery_id]).to eq("full_season")
    expect(Jumbotron::DiscoveryJob).not_to have_been_enqueued
  end

  it "defers provider cooldown through CommandTower continuation" do
    allow(adapter).to receive(:provider_cooling_down?).and_return(true)

    result = continue_from_job

    expect(result).to be_deferred
    expect(result.reason).to eq(:provider_cooldown)
    expect(result.retry_after).to eq(180)
    expect(Jumbotron::DiscoveryJob).to have_been_enqueued.with(
      adapter_id: "espn_nfl",
      discovery_id: "full_season",
      continuation_attempt: 2
    ).at(a_value_within(1.second).of(180.seconds.from_now))
  end

  it "defers lease contention with a 5 second wait" do
    allow(Jumbotron::Services::Adapters::ExecuteSynchronizationScope).to receive(:call).and_return(
      scope_outcome(:contention)
    )

    result = continue_from_job

    expect(result).to be_deferred
    expect(result.reason).to eq(:lease_contention)
    expect(result.retry_after).to eq(5)
    expect(Jumbotron::DiscoveryJob).to have_been_enqueued.with(
      hash_including(continuation_attempt: 2)
    ).at(a_value_within(1.second).of(5.seconds.from_now))
  end

  it "defers acquisition failure as provider cooldown" do
    allow(Jumbotron::Services::Adapters::ExecuteSynchronizationScope).to receive(:call).and_return(
      scope_outcome(:failed, failure_class: "acquisition")
    )

    result = continue_from_job

    expect(result).to be_deferred
    expect(result.reason).to eq(:provider_cooldown)
    expect(Jumbotron::DiscoveryJob).to have_been_enqueued
  end

  it "fails canonical and transform errors without continuation" do
    allow(Jumbotron::Services::Adapters::ExecuteSynchronizationScope).to receive(:call).and_return(
      scope_outcome(:failed, failure_class: "mutation")
    )

    result = continue_from_job

    expect(result).to be_failure
    expect(result).not_to be_deferred
    expect(Jumbotron::DiscoveryJob).not_to have_been_enqueued
  end

  it "fails unknown adapter identity without continuation" do
    result = described_class.call_from_job(
      job: job,
      continuation_attempt: 1,
      adapter_id: "missing",
      discovery_id: "full_season"
    )

    expect(result).to be_failure
    expect(result.errors.first[:code]).to eq("unknown_adapter")
    expect(Jumbotron::DiscoveryJob).not_to have_been_enqueued
  end

  it "does not enqueue continuation from HTTP .call when deferred" do
    allow(adapter).to receive(:provider_cooling_down?).and_return(true)

    result = described_class.call(adapter_id: "espn_nfl", discovery_id: "full_season")

    expect(result).to be_deferred
    expect(Jumbotron::DiscoveryJob).not_to have_been_enqueued
  end

  it "exhausts delayed continuation at max_attempts 24" do
    allow(adapter).to receive(:provider_cooling_down?).and_return(true)

    expect { continue_from_job(attempt: 24) }.to raise_error(
      CommandTower::Errors::ContinuationExhaustedError, /attempt 24 of 24/
    )
    expect(Jumbotron::DiscoveryJob).not_to have_been_enqueued
  end

  it "declares delayed continuation with a 24-attempt budget" do
    source = File.read(Jumbotron::Engine.root.join("app/workflows/jumbotron/workflows/execute_discovery_workflow.rb"))
    expect(source).to include("retry_strategy :delayed_continuation, max_attempts: 24")
    expect(source).not_to include("retry_on")
    expect(source).not_to include("set(wait:")
    expect(source).not_to include("180")
  end
end
