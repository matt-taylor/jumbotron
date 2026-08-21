# frozen_string_literal: true

RSpec.describe Jumbotron::Workflows::ExecuteGameUpdatePolicyWorkflow do
  include ActiveSupport::Testing::TimeHelpers

  let(:now) { Time.utc(2026, 8, 13, 18, 0, 0) }
  let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
  let(:sport) { create(:jumbotron_sport, name: "football") }
  let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
  let(:season) { create(:jumbotron_season, league: league, name: "2025") }
  let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }

  before do
    adapter.register! unless adapter.registered?
    league
  end

  def week_group(number)
    Jumbotron::ScheduleGroup.find_or_create_by!(
      season_id: season.id,
      season_phase_id: phase.id,
      kind: "week",
      name: "Week #{number}"
    ) do |group|
      group.number = number
    end
  end

  def build_game(scheduled_at:, lifecycle: "scheduled", group: week_group(4))
    create(
      :jumbotron_game,
      league: league,
      season: season,
      season_phase: phase,
      schedule_group: group,
      scheduled_at: scheduled_at,
      lifecycle: lifecycle
    )
  end

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

  around { |example| travel_to(now) { example.run } }

  it "resolves a known adapter and policy" do
    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_success
    expect(result.payload[:adapter_id]).to eq("espn_nfl")
    expect(result.payload[:policy_id]).to eq("upcoming")
    expect(result.payload[:eligible_games]).to eq(0)
    expect(result.payload[:unique_scopes]).to eq(0)
  end

  it "fails for an unknown adapter" do
    result = described_class.call(adapter_id: "missing", policy_id: "upcoming")

    expect(result).to be_failure
    expect(result.errors.first[:code]).to eq("unknown_adapter")
  end

  it "rejects discovery ids" do
    result = described_class.call(adapter_id: "espn_nfl", policy_id: "full_season")

    expect(result).to be_failure
    expect(result.errors.first[:code]).to eq("discovery_not_executable")
  end

  it "selects far_future and near_future through adapter predicates" do
    build_game(scheduled_at: now + 8.weeks)
    build_game(scheduled_at: now + 3.weeks)
    build_game(scheduled_at: now + 1.week)
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(sync_success)

    far = described_class.call(adapter_id: "espn_nfl", policy_id: "far_future")
    near = described_class.call(adapter_id: "espn_nfl", policy_id: "near_future")

    expect(far.payload[:eligible_games]).to eq(1)
    expect(near.payload[:eligible_games]).to eq(1)
  end

  it "selects only adapter-eligible games for upcoming" do
    upcoming = build_game(scheduled_at: now + 1.week)
    build_game(scheduled_at: now + 8.weeks)
    build_game(scheduled_at: now - 1.hour, lifecycle: "completed", group: week_group(3))

    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(sync_success)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_success
    expect(result.payload[:eligible_games]).to eq(1)
    expect(upcoming.reload.scheduled_at).to be_between(now, now + 2.weeks)
  end

  it "uses scheduled_at for live eligibility" do
    build_game(scheduled_at: now - 10.minutes, lifecycle: "scheduled")
    build_game(scheduled_at: now + 1.day)
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(sync_success)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "live")

    expect(result.payload[:eligible_games]).to eq(1)
  end

  it "keeps interrupted distinct from live" do
    build_game(scheduled_at: now - 1.hour, lifecycle: "postponed")
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(sync_success)

    live = described_class.call(adapter_id: "espn_nfl", policy_id: "live")
    interrupted = described_class.call(adapter_id: "espn_nfl", policy_id: "interrupted")

    expect(live.payload[:eligible_games]).to eq(0)
    expect(interrupted.payload[:eligible_games]).to eq(1)
  end

  it "deduplicates games in the same schedule group" do
    group4 = week_group(4)
    group5 = week_group(5)
    build_game(scheduled_at: now + 1.week, group: group4)
    build_game(scheduled_at: now + 8.days, group: group4)
    build_game(scheduled_at: now + 9.days, group: group5)
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(sync_success)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result.payload[:eligible_games]).to eq(3)
    expect(result.payload[:unique_scopes]).to eq(2)
    expect(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to have_received(:call).twice
  end

  it "skips incomplete grouping without calling synchronization" do
    build_game(scheduled_at: now + 1.week, group: nil)
    expect(Jumbotron::Workflows::SynchronizeAdapterWorkflow).not_to receive(:call)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_success
    expect(result.payload[:skipped_incomplete_scope]).to eq(1)
    expect(result.payload[:unique_scopes]).to eq(0)
  end

  it "is a successful no-op when no games are eligible" do
    expect(Jumbotron::Workflows::SynchronizeAdapterWorkflow).not_to receive(:call)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_success
    expect(result.payload[:eligible_games]).to eq(0)
  end

  it "skips acquisition when provider cooldown is active" do
    build_game(scheduled_at: now + 1.week)
    Jumbotron::Providers::Espn::Cooldown.new.record_failure!(
      CommandTower::Clients::Errors::UpstreamError.new(message: "down", details: { status: 503 })
    )
    expect(Jumbotron::Workflows::SynchronizeAdapterWorkflow).not_to receive(:call)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_success
    expect(result.payload[:skipped_cooldown]).to eq(1)
  end

  it "skips contended leases without failing the policy" do
    build_game(scheduled_at: now + 1.week, group: week_group(4))
    build_game(scheduled_at: now + 9.days, group: week_group(5))
    lease = Jumbotron::Synchronization::Lease.new
    held = lease.acquire(
      Jumbotron::Synchronization::Lease.scope(
        adapter_id: "espn_nfl",
        endpoint: :scoreboard,
        acquisition: { dates: 2025, season_type: 2, week: 4 }
      )
    )
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(sync_success)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_success
    expect(result.payload[:skipped_contention]).to eq(1)
    expect(result.payload[:succeeded_scopes]).to eq(1)
    expect(Jumbotron::Providers::Espn::Cooldown.new.cooling_down?).to be(false)
    lease.release(held.scope, token: held.token)
  end

  it "releases the lease after an unexpected synchronization exception" do
    build_game(scheduled_at: now + 1.week, group: week_group(4))
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_raise("boom")

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_failure
    retried = Jumbotron::Synchronization::Lease.new.acquire(
      Jumbotron::Synchronization::Lease.scope(
        adapter_id: "espn_nfl",
        endpoint: :scoreboard,
        acquisition: { dates: 2025, season_type: 2, week: 4 }
      )
    )
    expect(retried).to be_acquired
  end

  it "does not advance cooldown on canonical failure and continues other scopes" do
    build_game(scheduled_at: now + 1.week, group: week_group(4))
    build_game(scheduled_at: now + 9.days, group: week_group(5))
    calls = 0
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call) do
      calls += 1
      if calls == 1
        sync_failure(code: "normalization_failed", failure_class: "normalization")
      else
        sync_success
      end
    end

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_failure
    expect(result.meta[:execution][:failed_scopes]).to eq(1)
    expect(result.meta[:execution][:succeeded_scopes]).to eq(1)
    expect(Jumbotron::Providers::Espn::Cooldown.new.cooling_down?).to be(false)
  end

  it "short-circuits remaining ESPN scopes after provider acquisition failure" do
    build_game(scheduled_at: now + 1.week, group: week_group(4))
    build_game(scheduled_at: now + 9.days, group: week_group(5))
    allow(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to receive(:call).and_return(
      sync_failure(code: "acquisition_failed", failure_class: "acquisition")
    )
    allow(adapter).to receive(:provider_cooling_down?).and_return(false, true)

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_failure
    expect(Jumbotron::Workflows::SynchronizeAdapterWorkflow).to have_received(:call).once
    expect(result.meta[:execution][:failed_scopes]).to eq(1)
    expect(result.meta[:execution][:skipped_cooldown]).to eq(1)
  end
end
