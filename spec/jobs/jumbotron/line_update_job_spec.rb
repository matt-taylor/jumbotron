# frozen_string_literal: true

RSpec.describe Jumbotron::LineUpdateJob do
  describe "#perform" do
    before do
      allow(Jumbotron::Workflows::ExecuteLineUpdatePolicyWorkflow).to receive(:call_from_job).and_return(
        CommandTower::Workflows::WorkflowResult.success(payload: {}, http_status: :ok)
      )
    end

    context "when identity arguments are supplied" do
      before { described_class.perform_now(adapter_id: "espn_nfl", policy_id: "upcoming_lines") }

      it "invokes call_from_job" do
        expect(Jumbotron::Workflows::ExecuteLineUpdatePolicyWorkflow).to have_received(:call_from_job).with(
          adapter_id: "espn_nfl",
          policy_id: "upcoming_lines"
        )
      end
    end

    context "when scanning the job" do
      subject(:source) { File.read(Jumbotron::Engine.root.join("app/jobs/jumbotron/line_update_job.rb")) }

      it "does not call the workflow with plain .call" do
        expect(source).to include("call_from_job")
        expect(source).not_to match(/ExecuteLineUpdatePolicyWorkflow\.call\b/)
        expect(source).not_to include("GameUpdateJob")
      end

      it "contains no NFL or provider logic" do
        expect(source).not_to match(/Nfl|espn|eligible\?|seasontype|Scoreboard/)
        expect(source).to include("adapter_id")
        expect(source).to include("policy_id")
      end
    end
  end
end
