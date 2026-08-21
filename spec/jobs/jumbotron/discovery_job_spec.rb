# frozen_string_literal: true

RSpec.describe Jumbotron::DiscoveryJob do
  it "invokes ExecuteDiscoveryWorkflow through CommandTower execute_workflow" do
    allow(Jumbotron::Workflows::ExecuteDiscoveryWorkflow).to receive(:call_from_job).and_return(
      CommandTower::Workflows::WorkflowResult.success(payload: {}, http_status: :ok)
    )

    described_class.perform_now(adapter_id: "espn_nfl", discovery_id: "full_season")

    expect(Jumbotron::Workflows::ExecuteDiscoveryWorkflow).to have_received(:call_from_job).with(
      hash_including(
        adapter_id: "espn_nfl",
        discovery_id: "full_season",
        continuation_attempt: 1
      )
    )
  end

  it "contains no NFL or provider logic" do
    source = File.read(Jumbotron::Engine.root.join("app/jobs/jumbotron/discovery_job.rb"))
    expect(source).not_to match(/Nfl|espn|seasontype|Scoreboard|full_season/)
    expect(source).to include("adapter_id")
    expect(source).to include("discovery_id")
    expect(source).to include("execute_workflow")
    expect(source).not_to include("retry_on")
    expect(source).not_to include("set(wait:")
  end
end
