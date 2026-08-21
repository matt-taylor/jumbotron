# frozen_string_literal: true

RSpec.describe "Slice 2.5 recurring schedule materialization" do
  let(:root) { Jumbotron::Engine.root }

  it "keeps cadence on adapter policies and generic GameUpdateJob plus LineUpdateJob" do
    source = File.read(root.join("app/scheduling/jumbotron/scheduling/desired_schedules.rb"))
    expect(source).not_to match(/far_future|espn_nfl|weekly/)
    expect(File.read(root.join("app/jobs/jumbotron/game_update_job.rb"))).not_to match(
      /SolidQueue|Sidekiq|recurring|Fugit|cron/
    )
    expect(Jumbotron::Scheduling::DesiredSchedules.call.map(&:job_class_name).uniq).to contain_exactly(
      "Jumbotron::GameUpdateJob",
      "Jumbotron::LineUpdateJob"
    )
  end

  it "keeps scheduler APIs out of adapters and the executor workflow" do
    adapter_sources = Dir[root.join("app/adapters/**/*.rb")].map { |path| File.read(path) }.join("\n")
    workflow = File.read(root.join("app/workflows/jumbotron/workflows/execute_game_update_policy_workflow.rb"))
    expect(adapter_sources).not_to match(/SolidQueue|Sidekiq::Cron|Fugit|recurring\.yml/)
    expect(workflow).not_to match(/SolidQueue|Sidekiq|Fugit|recurring\.yml/)
    expect(workflow).to include("retry_strategy :scheduled_cadence")
  end

  it "does not require scheduler gems or introduce cadence bookkeeping" do
    scheduling = Dir[root.join("app/scheduling/**/*.rb")].map { |path| File.read(path) }.join("\n")
    expect(scheduling).not_to match(/^require ["']solid_queue["']/)
    expect(scheduling).not_to match(/^require ["']sidekiq/)
    expect(scheduling).not_to include("last_run_at")
    expect(scheduling).not_to include("next_run_at")
    expect(scheduling).not_to include("last_job_ran_at")
    expect(scheduling).not_to include("DoubleFloor")
    expect(scheduling).not_to include("pickem")
    expect(Dir[root.join("config/recurring.yml")]).to be_empty
  end

  it "exposes a zero-argument materialize rake task" do
    source = File.read(root.join("lib/tasks/jumbotron_schedules.rake"))
    expect(source).to include("task materialize: :environment")
    expect(source).not_to include("[solid_queue]")
  end
end
