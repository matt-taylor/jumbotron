# frozen_string_literal: true

RSpec.describe Jumbotron::GameUpdateJob do
  it "invokes the generic policy workflow with identity arguments" do
    allow(Jumbotron::Workflows::ExecuteGameUpdatePolicyWorkflow).to receive(:call_from_job).and_return(
      CommandTower::Workflows::WorkflowResult.success(payload: {}, http_status: :ok)
    )

    described_class.perform_now(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(Jumbotron::Workflows::ExecuteGameUpdatePolicyWorkflow).to have_received(:call_from_job).with(
      adapter_id: "espn_nfl",
      policy_id: "upcoming"
    )
  end

  it "supports multiple policy ids on the same job class" do
    allow(Jumbotron::Workflows::ExecuteGameUpdatePolicyWorkflow).to receive(:call_from_job).and_return(
      CommandTower::Workflows::WorkflowResult.success(payload: {}, http_status: :ok)
    )

    described_class.perform_now(adapter_id: "espn_nfl", policy_id: "live")
    described_class.perform_now(adapter_id: "espn_nfl", policy_id: "interrupted")

    expect(Jumbotron::Workflows::ExecuteGameUpdatePolicyWorkflow).to have_received(:call_from_job).with(
      adapter_id: "espn_nfl",
      policy_id: "live"
    )
    expect(Jumbotron::Workflows::ExecuteGameUpdatePolicyWorkflow).to have_received(:call_from_job).with(
      adapter_id: "espn_nfl",
      policy_id: "interrupted"
    )
  end

  it "contains no NFL or provider logic" do
    source = File.read(Jumbotron::Engine.root.join("app/jobs/jumbotron/game_update_job.rb"))
    expect(source).not_to match(/Nfl|espn|eligible\?|seasontype|Scoreboard/)
    expect(source).to include("adapter_id")
    expect(source).to include("policy_id")
  end
end
