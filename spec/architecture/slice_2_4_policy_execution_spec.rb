# frozen_string_literal: true

RSpec.describe "Slice 2.4 policy execution architecture" do
  let(:root) { Jumbotron::Engine.root }

  it "uses one generic job and one generic execution workflow" do
    expect(File).to exist(root.join("app/jobs/jumbotron/game_update_job.rb"))
    expect(File).to exist(root.join("app/workflows/jumbotron/workflows/execute_game_update_policy_workflow.rb"))
    expect(Dir[root.join("app/jobs/**/*far_future*")]).to be_empty
    expect(Dir[root.join("app/workflows/**/*nfl*")]).to be_empty
    expect(defined?(Jumbotron::CompetitionPeriod)).to be_nil
  end

  it "does not put week_number or ESPN query fields on Game" do
    expect(Jumbotron::Game.column_names).not_to include(
      "week_number", "espn_week", "espn_season_type", "matchweek"
    )
    expect(Jumbotron::Canonical::GameInput.members).not_to include(:week_number)
    expect(Jumbotron::Canonical::GameInput.members).to include(:schedule_group)
  end

  it "keeps generic execution free of ESPN query construction and grouping-kind switches" do
    source = File.read(root.join("app/workflows/jumbotron/workflows/execute_game_update_policy_workflow.rb"))
    expect(source).not_to match(/seasontype|season_type|dates:|kind ==/)
    expect(source).not_to include("acquisition_scope_for")
    expect(source).not_to include("SynchronizeAdapterWorkflow")
  end

  it "does not ship a host recurring.yml" do
    expect(Dir[root.join("config/recurring.yml")]).to be_empty
    expect(defined?(Jumbotron::SharedSequence)).to be_nil
    adapter_sources = Dir[root.join("app/adapters/**/*.rb")].map { |path| File.read(path) }.join("\n")
    job = File.read(root.join("app/jobs/jumbotron/game_update_job.rb"))
    workflow = File.read(root.join("app/workflows/jumbotron/workflows/execute_game_update_policy_workflow.rb"))
    expect(adapter_sources).not_to match(/Sidekiq::Cron|solid_queue_recurring/i)
    expect(job).not_to match(/Sidekiq::Cron|solid_queue_recurring/i)
    expect(workflow).not_to match(/Sidekiq::Cron|solid_queue_recurring/i)
  end
end
