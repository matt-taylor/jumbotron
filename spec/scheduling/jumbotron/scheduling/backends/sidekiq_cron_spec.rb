# frozen_string_literal: true

RSpec.describe Jumbotron::Scheduling::Backends::SidekiqCron do
  let(:job_class) { Jumbotron::SpecSupport::FakeSidekiqCronJob }
  let(:backend) { described_class.new(job_class: job_class) }
  let(:schedules) { Jumbotron::Scheduling::DesiredSchedules.call }

  before { job_class.reset! }

  it "translates cadence to five-field UTC cron without NFL policy ids" do
    expect(backend.cron_string(Jumbotron::Adapters::Cadence.new(every: 5, unit: :minute))).to eq("*/5 * * * *")
    expect(backend.cron_string(Jumbotron::Adapters::Cadence.new(every: 1, unit: :hour))).to eq("17 * * * *")
    expect(backend.cron_string(Jumbotron::Adapters::Cadence.new(every: 1, unit: :day))).to eq("17 6 * * *")
    expect(backend.cron_string(Jumbotron::Adapters::Cadence.new(every: 1, unit: :week))).to eq("17 6 * * 3")
  end

  it "reconciles jumbotron:* names and preserves Pick'em-shaped host jobs" do
    job_class.create("name" => "Sunday Weekly Reminder", "class" => "WeeklyReminderWorker", "cron" => "0 16 * * 0")
    job_class.create("name" => "Populate week with all games", "class" => "PopulateNextWeek", "cron" => "30 8 * * 3")
    job_class.create(
      "name" => "jumbotron:espn_nfl:old_policy",
      "class" => "Jumbotron::GameUpdateJob",
      "cron" => "0 * * * *",
      "args" => [{ "adapter_id" => "espn_nfl", "policy_id" => "old_policy" }]
    )

    backend.materialize(schedules)
    names = job_class.all.map(&:name)

    expect(names).to include("Sunday Weekly Reminder", "Populate week with all games")
    expect(names).not_to include("jumbotron:espn_nfl:old_policy")
    expect(names).to include(
      "jumbotron:espn_nfl:far_future",
      "jumbotron:espn_nfl:near_future",
      "jumbotron:espn_nfl:upcoming",
      "jumbotron:espn_nfl:live",
      "jumbotron:espn_nfl:interrupted",
      "jumbotron:espn_nfl:far_future_lines",
      "jumbotron:espn_nfl:upcoming_lines",
      "jumbotron:espn_nfl:in_progress_lines"
    )
    live = job_class.registry.fetch("jumbotron:espn_nfl:live")
    expect(live.klass).to eq("Jumbotron::GameUpdateJob")
    expect(live.cron).to eq("*/2 * * * *")
    expect(live.args).to eq([{ "adapter_id" => "espn_nfl", "policy_id" => "live" }])
    lines = job_class.registry.fetch("jumbotron:espn_nfl:in_progress_lines")
    expect(lines.klass).to eq("Jumbotron::LineUpdateJob")
    expect(lines.cron).to eq("17 * * * *")

    snapshot = job_class.all.map { |job| [job.name, job.cron, job.args] }
    backend.materialize(schedules)
    expect(job_class.all.map { |job| [job.name, job.cron, job.args] }).to eq(snapshot)
  end
end
