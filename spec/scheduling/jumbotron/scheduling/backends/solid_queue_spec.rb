# frozen_string_literal: true

require "tmpdir"

RSpec.describe Jumbotron::Scheduling::Backends::SolidQueue do
  include ActiveSupport::Testing::TimeHelpers

  let(:backend) { described_class.new }
  let(:schedules) { Jumbotron::Scheduling::DesiredSchedules.call }

  def load_yaml(path)
    YAML.safe_load_file(path)
  end

  it "translates cadence units without NFL policy ids" do
    cadence = Jumbotron::Adapters::Cadence.new(every: 5, unit: :minute)
    expect(backend.schedule_string(cadence)).to eq("every 5 minutes")
    expect(backend.schedule_string(Jumbotron::Adapters::Cadence.new(every: 30, unit: :second)))
      .to eq("every 30 seconds")
    expect(backend.schedule_string(Jumbotron::Adapters::Cadence.new(every: 1, unit: :hour)))
      .to eq("every hour at minute 17")
    expect(backend.schedule_string(Jumbotron::Adapters::Cadence.new(every: 1, unit: :day)))
      .to eq("every day at 6:17 am")
    expect(backend.schedule_string(Jumbotron::Adapters::Cadence.new(every: 1, unit: :week)))
      .to eq("every wednesday at 6:17 am")
  end

  it "reconciles jumbotron:* keys and preserves host jobs in a DFM-shaped file" do
    Dir.mktmpdir do |dir|
      path = Pathname.new(dir).join("recurring.yml")
      path.write(<<~YAML)
        production:
          clear_solid_queue_finished_jobs:
            command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
            schedule: every hour at minute 12
        test:
          host_cleanup:
            class: HostCleanupJob
            schedule: every hour
          host_digest:
            class: HostDigestJob
            schedule: every day at 9am
          jumbotron:espn_nfl:old_policy:
            class: Jumbotron::GameUpdateJob
            args:
              - adapter_id: espn_nfl
                policy_id: old_policy
            schedule: every hour
      YAML

      backend.materialize(schedules, path: path)
      doc = load_yaml(path)
      test_section = doc.fetch("test")

      expect(doc.fetch("production").keys).to eq(["clear_solid_queue_finished_jobs"])
      expect(test_section["host_cleanup"]).to eq("class" => "HostCleanupJob", "schedule" => "every hour")
      expect(test_section["host_digest"]).to eq("class" => "HostDigestJob", "schedule" => "every day at 9am")
      expect(test_section.keys).not_to include("jumbotron:espn_nfl:old_policy")
      %w[far_future near_future upcoming live interrupted].each do |policy_id|
        key = "jumbotron:espn_nfl:#{policy_id}"
        expect(test_section[key]["class"]).to eq("Jumbotron::GameUpdateJob")
        expect(test_section[key]["args"]).to eq([{ "adapter_id" => "espn_nfl", "policy_id" => policy_id }])
      end
      %w[far_future_lines near_future_lines upcoming_lines in_progress_lines interrupted_lines].each do |policy_id|
        key = "jumbotron:espn_nfl:#{policy_id}"
        expect(test_section[key]["class"]).to eq("Jumbotron::LineUpdateJob")
        expect(test_section[key]["args"]).to eq([{ "adapter_id" => "espn_nfl", "policy_id" => policy_id }])
      end
      expect(test_section["jumbotron:espn_nfl:live"]["schedule"]).to eq("every 30 seconds")

      first = path.read
      backend.materialize(schedules, path: path)
      expect(path.read).to eq(first)
    end
  end
end
