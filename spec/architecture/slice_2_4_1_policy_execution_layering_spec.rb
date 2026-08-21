# frozen_string_literal: true

RSpec.describe "Slice 2.4.1 policy execution layering" do
  let(:root) { Jumbotron::Engine.root }

  it "keeps GameUpdateJob on call_from_job with identity arguments only" do
    source = File.read(root.join("app/jobs/jumbotron/game_update_job.rb"))
    expect(source).to include("call_from_job")
    expect(source).not_to match(/ExecuteGameUpdatePolicyWorkflow\.call\b/)
    expect(source).to include("adapter_id")
    expect(source).to include("policy_id")
    expect(source).not_to match(/Nfl|espn|eligible\?|seasontype|Scoreboard/)
  end

  it "keeps ActiveRecord, lease mechanics, and terminal filters out of the executor workflow" do
    source = File.read(root.join("app/workflows/jumbotron/workflows/execute_game_update_policy_workflow.rb"))
    expect(source).not_to match(/Game\.where|Sport\.where|League\.where/)
    expect(source).not_to match(/Lease\.new|Lease\.acquire|Lease\.release/)
    expect(source).not_to include("TERMINAL_LIFECYCLES")
    expect(source).not_to include("SynchronizeAdapterWorkflow")
    expect(source).not_to include("acquisition_scope_for")
    expect(source).to include("retry_strategy :scheduled_cadence")
    expect(source).to include("SelectEligibleGames")
    expect(source).to include("BuildAcquisitionScopes")
    expect(source).to include("ExecuteSynchronizationScope")
  end

  it "invokes SynchronizeAdapterWorkflow only from ExecuteSynchronizationScope in app code" do
    callers = Dir[root.join("app/**/*.rb")].select do |path|
      File.read(path).include?("SynchronizeAdapterWorkflow.call")
    end
    expect(callers).to eq([
                            root.join("app/services/jumbotron/services/adapters/execute_synchronization_scope.rb").to_s
                          ])
  end

  it "does not introduce SharedSequences, engine-shipped recurring.yml, or Game.week_number" do
    expect(defined?(Jumbotron::SharedSequence)).to be_nil
    expect(Dir[root.join("config/recurring.yml")]).to be_empty
    expect(Jumbotron::Game.column_names).not_to include("week_number")
  end
end
