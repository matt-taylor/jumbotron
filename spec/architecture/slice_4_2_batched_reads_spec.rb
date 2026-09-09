# frozen_string_literal: true

RSpec.describe "Slice 4.2 batched public reads" do
  let(:root) { Jumbotron::Engine.root }

  it "retains batched reads beside the accepted sandbox control plane" do
    expect(Jumbotron.client).to be_a(Jumbotron::Client)
    expect(Jumbotron::Client.public_instance_methods(false)).to contain_exactly(
      :schedule, :schedule_groups, :game, :consensus, :current_lines,
      :register_sandbox_projection, :reset_sandbox_projection, :sandbox_projection
    )
  end

  it "keeps dedicated Read workflows without sibling Workflow calls or AR" do
    %w[
      read_schedule_workflow.rb
      read_schedule_groups_workflow.rb
      read_game_workflow.rb
      read_consensus_workflow.rb
      read_current_lines_workflow.rb
    ].each do |name|
      source = File.read(root.join("app/workflows/jumbotron/workflows", name))
      expect(source).to include("retry_strategy :none")
      expect(source).not_to match(/Game\.where|LineObservation\.where/)
      expect(source).not_to include("ReadConsensusWorkflow.call")
      expect(source).not_to include("ReadCurrentLinesWorkflow.call")
      expect(source).not_to include("ReadGameWorkflow.call")
      expect(source).not_to include("ReadScheduleWorkflow.call")
      expect(source).not_to include("ReadScheduleGroupsWorkflow.call")
      expect(source).not_to include("CompetitionOdds")
      expect(source).not_to include("LineUpdateJob")
    end
  end

  it "does not loop Phase 3 single-Game resolvers in Public collection services" do
    resolve = File.read(root.join("app/services/jumbotron/services/public/resolve_current_lines_for_games.rb"))
    derive = File.read(root.join("app/services/jumbotron/services/public/derive_consensus_for_games.rb"))
    included = File.read(root.join("app/services/jumbotron/services/public/load_included_lines.rb"))
    expect(resolve).not_to include("ResolveCurrentLines.call(game:")
    expect(resolve).not_to include(".each do |game|")
    expect(derive).not_to include("DeriveConsensusLine.call(game:")
    expect(derive).not_to include(".each do |game|")
    expect(included).to include("DeriveConsensusForGames.call")
    expect(included).to include("current_lines:")
  end

  it "keeps batch Current Line resolution set-oriented in Canonical below Workflow" do
    source = File.read(root.join("app/services/jumbotron/services/canonical/resolve_current_lines_for_games.rb"))
    expect(source).to include("< CommandTower::Services::ApplicationService")
    expect(source).not_to include("ResolveCurrentLines.call(game:")
    expect(source).not_to include(".each do |game_id|")
  end

  it "does not introduce Current Line or Consensus tables" do
    migrations = Dir[root.join("db/migrate/*.rb")].map { |path| File.read(path) }.join("\n")
    expect(migrations).not_to match(/create_table ["']jumbotron_current_lines["']/)
    expect(migrations).not_to match(/create_table ["']jumbotron_consensus_lines["']/)
  end
end
