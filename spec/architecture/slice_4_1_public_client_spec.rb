# frozen_string_literal: true

RSpec.describe "Slice 4.1 public client workflow boundary" do
  let(:root) { Jumbotron::Engine.root }
  let(:client_source) { File.read(root.join("lib/jumbotron/client.rb")) }
  let(:workflow_sources) do
    %w[
      read_schedule_workflow.rb
      read_schedule_groups_workflow.rb
      read_game_workflow.rb
      read_games_workflow.rb
      read_consensus_workflow.rb
      read_current_lines_workflow.rb
    ].map { |name| File.read(root.join("app/workflows/jumbotron/workflows", name)) }
  end

  it "exposes Jumbotron.client as Jumbotron::Client" do
    expect(Jumbotron.client).to be_a(Jumbotron::Client)
  end

  it "exposes only accepted public methods" do
    expect(Jumbotron::Client.public_instance_methods(false)).to contain_exactly(
      :schedule, :schedule_groups, :game, :games, :consensus, :current_lines,
      :sandbox_projection, :register_sandbox_projection, :reset_sandbox_projection
    )
  end

  it "keeps ActiveRecord, ESPN, and adapters out of the Client" do
    expect(client_source).not_to match(/Game\.where|LineObservation\.where/)
    expect(client_source).not_to include("CompetitionOdds")
    expect(client_source).not_to include("Adapters")
    expect(client_source).not_to include("WorkflowResult")
    expect(client_source).not_to include("ServiceResult")
  end

  it "gives each public operation a dedicated workflow with retry_strategy :none" do
    expect(defined?(Jumbotron::Workflows::ReadScheduleWorkflow)).not_to be_nil
    expect(defined?(Jumbotron::Workflows::ReadScheduleGroupsWorkflow)).not_to be_nil
    expect(defined?(Jumbotron::Workflows::ReadGameWorkflow)).not_to be_nil
    expect(defined?(Jumbotron::Workflows::ReadGamesWorkflow)).not_to be_nil
    expect(defined?(Jumbotron::Workflows::ReadConsensusWorkflow)).not_to be_nil
    expect(defined?(Jumbotron::Workflows::ReadCurrentLinesWorkflow)).not_to be_nil
    workflow_sources.each do |source|
      expect(source).to include("retry_strategy :none")
      expect(source).not_to match(/Game\.where|LineObservation\.where/)
      expect(source).not_to include("CompetitionOdds")
      expect(source).not_to include("Adapters")
      expect(source).not_to include("LineUpdateJob")
      expect(source).not_to include("GameUpdateJob")
    end
  end

  it "does not let public workflows call sibling workflows" do
    game = File.read(root.join("app/workflows/jumbotron/workflows/read_game_workflow.rb"))
    schedule = File.read(root.join("app/workflows/jumbotron/workflows/read_schedule_workflow.rb"))
    schedule_groups = File.read(root.join("app/workflows/jumbotron/workflows/read_schedule_groups_workflow.rb"))
    expect(game).not_to include("ReadConsensusWorkflow")
    expect(game).not_to include("ReadCurrentLinesWorkflow")
    expect(schedule).not_to include("ReadConsensusWorkflow")
    expect(schedule).not_to include("ReadCurrentLinesWorkflow")
    expect(schedule).not_to include("ReadGameWorkflow")
    expect(schedule_groups).not_to include("ReadScheduleWorkflow")
    expect(schedule_groups).not_to include("ReadGameWorkflow")
  end

  it "does not copy Phase 3 consensus arithmetic into public workflows" do
    joined = workflow_sources.join("\n")
    expect(joined).not_to include("CONSENSUS_MARKETS")
    expect(joined).not_to include("LIVE_ODDS_NAME")
    expect(joined).not_to include("BigDecimal")
  end

  it "keeps public POROs off ActiveRecord" do
    expect(Jumbotron::Public::Game.ancestors).not_to include(ActiveRecord::Base)
    expect(Jumbotron::Public::GameProgress.ancestors).not_to include(ActiveRecord::Base)
    expect(Jumbotron::Public::Schedule.ancestors).not_to include(ActiveRecord::Base)
    expect(Jumbotron::Public::ScheduleGroupEnumeration.ancestors).not_to include(ActiveRecord::Base)
    expect(Jumbotron::Public::CurrentLine.ancestors).not_to include(ActiveRecord::Base)
    expect(Jumbotron::Public::ConsensusLine.ancestors).not_to include(ActiveRecord::Base)
  end
end
