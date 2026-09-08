# frozen_string_literal: true

RSpec.describe "Slice 2.6 boot discovery architecture" do
  let(:root) { Jumbotron::Engine.root }

  it "boots a generic DiscoveryJob without ESPN I/O in the Engine" do
    engine = File.read(root.join("lib/jumbotron/engine.rb"))
    expect(engine).to include("config.boot_discovery")
    expect(engine).to include("Jumbotron::Boot::EnqueueDiscoveries.call")
    expect(engine).not_to match(/Clients\.espn|Scoreboard\.acquire|expand_full_season/)
    expect(engine).not_to include("to_prepare")
    expect(engine).not_to include("on_worker_boot")

    job = File.read(root.join("app/jobs/jumbotron/discovery_job.rb"))
    expect(job).to include("execute_workflow")
    expect(job).to include("adapter_id")
    expect(job).to include("discovery_id")
    expect(job).not_to include("retry_on")
    expect(job).not_to include("set(wait:")
    expect(job).not_to match(/Nfl|espn|Scoreboard/)
  end

  it "keeps discovery out of 2.5 recurring schedules and GameUpdate cadence" do
    Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered?
    ids = Jumbotron::Scheduling::DesiredSchedules.call.map(&:id)
    expect(ids).not_to include("jumbotron:espn_nfl:full_season")
    expect(ids).to include("jumbotron:espn_nfl:live")
    expect(ids).to include("jumbotron:espn_nfl:upcoming_lines")
    expect(ids).to include("jumbotron:espn_nfl:post_final_record")
    expect(ids.grep(/\Ajumbotron:espn_nfl:/).size).to eq(11)
    expect(ids.grep(/\Ajumbotron:sandbox_nfl:/).size).to eq(11)
    expect(ids).not_to include("jumbotron:sandbox_nfl:full_season")

    game_update = File.read(root.join("app/jobs/jumbotron/game_update_job.rb"))
    expect(game_update).to include("call_from_job")
    expect(game_update).not_to include("execute_workflow")

    policy = File.read(root.join("app/workflows/jumbotron/workflows/execute_game_update_policy_workflow.rb"))
    expect(policy).to include("retry_strategy :scheduled_cadence")
    expect(policy).not_to include("delayed_continuation")
  end

  it "does not introduce SharedSequences or discovery rows in host scheduler YAML" do
    expect(defined?(Jumbotron::SharedSequence)).to be_nil
    expect(defined?(Jumbotron::SharedSequences)).to be_nil
    expect(Dir[root.join("config/recurring.yml")]).to be_empty
    scheduling = Dir[root.join("app/scheduling/**/*.rb")].map { |path| File.read(path) }.join("\n")
    expect(scheduling).not_to include("DiscoveryJob")
    expect(scheduling).not_to include("full_season")
  end

  it "invokes SynchronizeAdapterWorkflow only from ExecuteSynchronizationScope" do
    callers = Dir[root.join("app/**/*.rb")].select do |path|
      File.read(path).include?("SynchronizeAdapterWorkflow.call")
    end
    expect(callers).to eq([
                            root.join("app/services/jumbotron/services/adapters/execute_synchronization_scope.rb").to_s
                          ])
  end

  it "keeps NFL free of acquisition_scopes and week-constant enumeration" do
    source = File.read(root.join("app/adapters/jumbotron/adapters/espn/nfl.rb"))
    expect(source).not_to include("acquisition_scopes")
    expect(source).to include("scopes_for_discovery")
    expect(source).to include("expand_full_season")
  end
end
