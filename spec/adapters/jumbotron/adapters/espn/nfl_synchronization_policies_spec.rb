# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Espn::Nfl, "synchronization policies" do
  let(:adapter) { described_class }
  let(:now) { Time.utc(2026, 8, 13, 12, 0, 0) }

  def game(lifecycle:, scheduled_at:)
    instance_double(Jumbotron::Game, lifecycle: lifecycle, scheduled_at: scheduled_at)
  end

  describe "identity" do
    it "exposes adapter_id and game plus line policy ids with explicit types" do
      expect(adapter.adapter_id).to eq("espn_nfl")
      expect(adapter.policy_ids).to contain_exactly(
        :far_future, :near_future, :upcoming, :live, :interrupted,
        :far_future_lines, :near_future_lines, :upcoming_lines, :in_progress_lines, :interrupted_lines
      )

      expect(adapter.policy(:far_future).type).to eq(:future_game_update)
      expect(adapter.policy(:near_future).type).to eq(:future_game_update)
      expect(adapter.policy(:upcoming).type).to eq(:future_game_update)
      expect(adapter.policy(:live).type).to eq(:live_game_update)
      expect(adapter.policy(:interrupted).type).to eq(:interrupted_game_update)
      expect(adapter.policy(:far_future_lines).type).to eq(:future_line_update)
      expect(adapter.policy(:near_future_lines).type).to eq(:future_line_update)
      expect(adapter.policy(:upcoming_lines).type).to eq(:future_line_update)
      expect(adapter.policy(:in_progress_lines).type).to eq(:live_line_update)
      expect(adapter.policy(:interrupted_lines).type).to eq(:interrupted_line_update)
    end

    it "fails clearly for unknown policy ids" do
      expect { adapter.policy(:unknown) }.to raise_error(
        Jumbotron::Adapters::UnknownPolicyError, /unknown/
      )
    end
  end

  describe "cadence" do
    it "exposes cadence for recurring update policies" do
      expect(adapter.policy(:far_future).cadence.interval_seconds).to eq(604_800)
      expect(adapter.policy(:near_future).cadence.interval_seconds).to eq(86_400)
      expect(adapter.policy(:upcoming).cadence.interval_seconds).to eq(3600)
      expect(adapter.policy(:live).cadence.interval_seconds).to eq(60)
      expect(adapter.policy(:interrupted).cadence.interval_seconds).to eq(3600)
      expect(adapter.policy(:far_future_lines).cadence.interval_seconds).to eq(604_800)
      expect(adapter.policy(:near_future_lines).cadence.interval_seconds).to eq(86_400)
      expect(adapter.policy(:upcoming_lines).cadence.interval_seconds).to eq(3600)
      expect(adapter.policy(:in_progress_lines).cadence.interval_seconds).to eq(3600)
      expect(adapter.policy(:interrupted_lines).cadence.interval_seconds).to eq(3600)
    end
  end

  describe "eligibility boundaries" do
    it "classifies far / near / upcoming by scheduled_at windows" do
      far = game(lifecycle: "scheduled", scheduled_at: now + 6.weeks + 1.second)
      near_hi = game(lifecycle: "scheduled", scheduled_at: now + 6.weeks)
      near_lo = game(lifecycle: "scheduled", scheduled_at: now + 2.weeks)
      upcoming = game(lifecycle: "scheduled", scheduled_at: now + 2.weeks - 1.second)
      past = game(lifecycle: "scheduled", scheduled_at: now - 1.minute)

      expect(adapter.policy(:far_future).eligible?(far, now: now)).to be(true)
      expect(adapter.policy(:far_future).eligible?(near_hi, now: now)).to be(false)

      expect(adapter.policy(:near_future).eligible?(near_hi, now: now)).to be(true)
      expect(adapter.policy(:near_future).eligible?(near_lo, now: now)).to be(true)
      expect(adapter.policy(:near_future).eligible?(far, now: now)).to be(false)

      expect(adapter.policy(:upcoming).eligible?(upcoming, now: now)).to be(true)
      expect(adapter.policy(:upcoming).eligible?(near_lo, now: now)).to be(false)
      expect(adapter.policy(:upcoming).eligible?(past, now: now)).to be(false)
    end

    it "treats live vs interrupted vs terminal distinctly" do
      live = game(lifecycle: "in_progress", scheduled_at: now - 1.hour)
      postponed = game(lifecycle: "postponed", scheduled_at: now - 1.hour)
      suspended = game(lifecycle: "suspended", scheduled_at: now - 1.hour)
      completed = game(lifecycle: "completed", scheduled_at: now - 1.hour)
      cancelled = game(lifecycle: "cancelled", scheduled_at: now + 1.day)

      expect(adapter.policy(:live).eligible?(live, now: now)).to be(true)
      expect(adapter.policy(:live).eligible?(postponed, now: now)).to be(false)
      expect(adapter.policy(:live).eligible?(suspended, now: now)).to be(false)
      expect(adapter.policy(:live).eligible?(completed, now: now)).to be(false)

      expect(adapter.policy(:interrupted).eligible?(postponed, now: now)).to be(true)
      expect(adapter.policy(:interrupted).eligible?(suspended, now: now)).to be(true)
      expect(adapter.policy(:interrupted).eligible?(live, now: now)).to be(false)

      expect(adapter.policy(:far_future).eligible?(cancelled, now: now)).to be(false)
      expect(adapter.policy(:upcoming).eligible?(completed, now: now)).to be(false)

      expect(adapter.policy(:in_progress_lines).eligible?(live, now: now)).to be(true)
      expect(adapter.policy(:in_progress_lines).eligible?(postponed, now: now)).to be(false)
      expect(adapter.policy(:interrupted_lines).eligible?(postponed, now: now)).to be(true)
      expect(adapter.policy(:upcoming_lines).eligible?(completed, now: now)).to be(false)
      expect(adapter.policy(:far_future_lines).eligible?(cancelled, now: now)).to be(false)
    end
  end

  describe "full_season discovery" do
    it "declares discovery intent without cadence or request enumeration" do
      definition = adapter.discovery(:full_season)

      expect(definition.id).to eq(:full_season)
      expect(definition.endpoint).to eq(:scoreboard)
      expect(definition).not_to respond_to(:cadence)
      expect(adapter).not_to be_const_defined(:PRESEASON_WEEKS)
      expect(adapter).not_to be_const_defined(:REGULAR_WEEKS)
      expect(adapter).not_to be_const_defined(:POSTSEASON_WEEKS)
    end

    it "fails clearly for unknown discovery ids" do
      expect { adapter.discovery(:unknown) }.to raise_error(
        Jumbotron::Adapters::UnknownDiscoveryError, /unknown/
      )
    end

    it "delegates week expansion to Scoreboard.expand_full_season" do
      definition = adapter.discovery(:full_season)
      allow(Jumbotron::Providers::Espn::Resources::Scoreboard).to receive(:expand_full_season).and_return(
        CommandTower::Clients::ClientResult.success(output: [{ dates: 2026, season_type: 2, week: 1 }])
      )

      result = adapter.scopes_for_discovery(definition)

      expect(result).to be_success
      expect(Jumbotron::Providers::Espn::Resources::Scoreboard).to have_received(:expand_full_season).with(
        adapter: adapter,
        season_year: Time.current.utc.year
      )
    end
  end
end
