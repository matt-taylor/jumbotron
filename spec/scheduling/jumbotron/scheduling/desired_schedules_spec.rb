# frozen_string_literal: true

RSpec.describe Jumbotron::Scheduling::DesiredSchedules do
  let(:schedules) { described_class.call }
  let(:ids) { schedules.map(&:id) }
  let(:policy_ids) do
    %w[
      far_future near_future upcoming live interrupted post_final_record
      far_future_lines near_future_lines upcoming_lines in_progress_lines interrupted_lines
    ]
  end
  let(:expected_ids) do
    %w[espn_nfl sandbox_nfl].product(policy_ids).map do |adapter_id, policy_id|
      "jumbotron:#{adapter_id}:#{policy_id}"
    end
  end

  before do
    Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered?
    Jumbotron::Adapters::Sandbox::Nfl.register! unless Jumbotron::Adapters::Sandbox::Nfl.registered?
  end

  it "materializes game and line policies for every registered NFL adapter" do
    expect(ids).to match_array(expected_ids)
    expect(ids).not_to include("jumbotron:espn_nfl:full_season")
    expect(ids).not_to include("jumbotron:sandbox_nfl:full_season")
    expect(schedules.select { |row| row.arguments["policy_id"] == "upcoming" }.map(&:job_class_name).uniq).to eq(
      ["Jumbotron::GameUpdateJob"]
    )
    expect(
      schedules.select { |row| row.arguments["policy_id"] == "upcoming_lines" }.map(&:job_class_name).uniq
    ).to eq(["Jumbotron::LineUpdateJob"])
    expect(schedules.map { |row| row.arguments.keys }.uniq).to eq([%w[adapter_id policy_id]])
  end

  context "when reading adapter-declared cadence" do
    let(:live) do
      schedules.find do |schedule|
        schedule.arguments == { "adapter_id" => "sandbox_nfl", "policy_id" => "live" }
      end
    end

    it "uses the adapter cadence rather than a central NFL table" do
      expect(live.cadence).to eq(Jumbotron::Adapters::Sandbox::Nfl.policy(:live).cadence)
      expect(live.cadence.interval_seconds).to eq(60)
    end
  end

  context "with an unregistered adapter class" do
    let(:orphan) do
      Class.new(Jumbotron::Adapters::Base) do
        def self.name
          "Jumbotron::Adapters::SpecUnregisteredSchedules"
        end

        adapter_id "ghost_nfl"
        provider :espn
        sport "football"
        league "ghost"
        policy :upcoming,
               type: :future_game_update,
               cadence: Jumbotron::Adapters::Cadence.new(every: 1, unit: :hour),
               eligible: ->(*) { true }
      end
    end

    before { stub_const("Jumbotron::Adapters::SpecUnregisteredSchedules", orphan) }

    it "omits the adapter" do
      expect(schedules.map { |schedule| schedule.arguments["adapter_id"] }).not_to include("ghost_nfl")
    end
  end

  context "with an additional registered adapter" do
    let(:extra) do
      Class.new(Jumbotron::Adapters::Base) do
        def self.name
          "Jumbotron::Adapters::SpecSecondSchedules"
        end

        adapter_id "spec_other"
        provider :espn
        sport "football"
        league "other"
        policy :live,
               type: :live_game_update,
               cadence: Jumbotron::Adapters::Cadence.new(every: 5, unit: :minute),
               eligible: ->(*) { true }
        discovery :full_season, endpoint: :scoreboard
        register!
      end
    end

    before do
      stub_const("Jumbotron::Adapters::SpecSecondSchedules", extra)
      extra.register!
    end

    after do
      Jumbotron::Adapters::Registry.reset!
      Jumbotron::Adapters::Espn::Nfl.register!
      Jumbotron::Adapters::Sandbox::Nfl.register!
    end

    it "includes cadence policies without a central registry table" do
      expect(ids).to include("jumbotron:spec_other:live")
      expect(ids).not_to include("jumbotron:spec_other:full_season")
    end
  end
end
