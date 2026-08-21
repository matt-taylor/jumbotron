# frozen_string_literal: true

RSpec.describe Jumbotron::Scheduling::DesiredSchedules do
  before { Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered? }

  it "materializes NFL game and line update policies and excludes discovery" do
    schedules = described_class.call
    ids = schedules.map(&:id)

    expect(ids).to contain_exactly(
      "jumbotron:espn_nfl:far_future",
      "jumbotron:espn_nfl:near_future",
      "jumbotron:espn_nfl:upcoming",
      "jumbotron:espn_nfl:live",
      "jumbotron:espn_nfl:interrupted",
      "jumbotron:espn_nfl:far_future_lines",
      "jumbotron:espn_nfl:near_future_lines",
      "jumbotron:espn_nfl:upcoming_lines",
      "jumbotron:espn_nfl:in_progress_lines",
      "jumbotron:espn_nfl:interrupted_lines"
    )
    expect(ids).not_to include("jumbotron:espn_nfl:full_season")
    game_jobs = schedules.select { |schedule| schedule.arguments["policy_id"] == "upcoming" }
    line_jobs = schedules.select { |schedule| schedule.arguments["policy_id"] == "upcoming_lines" }
    expect(game_jobs.map(&:job_class_name).uniq).to eq(["Jumbotron::GameUpdateJob"])
    expect(line_jobs.map(&:job_class_name).uniq).to eq(["Jumbotron::LineUpdateJob"])
    schedules.each do |schedule|
      expect(schedule.arguments.keys).to contain_exactly("adapter_id", "policy_id")
      expect(schedule.arguments["adapter_id"]).to eq("espn_nfl")
    end
  end

  it "uses adapter-declared cadence rather than a central NFL table" do
    adapter = Jumbotron::Adapters::Espn::Nfl
    live = described_class.call.find { |schedule| schedule.arguments["policy_id"] == "live" }

    expect(live.cadence).to eq(adapter.policy(:live).cadence)
    expect(live.cadence.interval_seconds).to eq(120)
  end

  it "omits unregistered adapters" do
    orphan = Class.new(Jumbotron::Adapters::Base) do
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
    stub_const("Jumbotron::Adapters::SpecUnregisteredSchedules", orphan)

    ids = described_class.call.map { |schedule| schedule.arguments["adapter_id"] }
    expect(ids).not_to include("ghost_nfl")
  end

  it "includes a second registered adapter without a central registry table" do
    extra = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecSecondSchedules"
      end

      adapter_id "spec_other"
      provider :espn
      sport "football"
      league "other"
      policy :live, type: :live_game_update, cadence: Jumbotron::Adapters::Cadence.new(every: 5, unit: :minute),
                    eligible: ->(*) { true }
      discovery :full_season, endpoint: :scoreboard
      register!
    end
    stub_const("Jumbotron::Adapters::SpecSecondSchedules", extra)
    extra.register!

    ids = described_class.call.map(&:id)
    expect(ids).to include("jumbotron:spec_other:live")
    expect(ids).not_to include("jumbotron:spec_other:full_season")
  ensure
    Jumbotron::Adapters::Registry.reset!
    Jumbotron::Adapters::Espn::Nfl.register!
  end
end
