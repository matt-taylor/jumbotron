# frozen_string_literal: true

RSpec.describe "Slice 3.3 current lines consensus and line update" do
  let(:root) { Jumbotron::Engine.root }

  context "when scanning for persisted current or consensus tables" do
    it "does not persist CurrentLine or ConsensusLine" do
      expect(defined?(Jumbotron::CurrentLine)).to be_nil
      expect(defined?(Jumbotron::ConsensusLine)).to be_nil
      expect(Dir[root.join("db/migrate/*current_line*")]).to be_empty
      expect(Dir[root.join("db/migrate/*consensus*")]).to be_empty
    end
  end

  context "when scanning current-line and consensus services" do
    subject(:read_sources) do
      [
        File.read(root.join("app/services/jumbotron/services/canonical/resolve_current_lines.rb")),
        File.read(root.join("app/services/jumbotron/services/canonical/derive_consensus_line.rb"))
      ].join("\n")
    end

    it "does not perform ESPN I/O" do
      expect(read_sources).not_to include("CompetitionOdds")
      expect(read_sources).not_to include("acquire")
      expect(read_sources).not_to include("LineUpdateJob")
    end
  end

  context "when scanning the line update workflow" do
    subject(:workflow) do
      File.read(root.join("app/workflows/jumbotron/workflows/execute_line_update_policy_workflow.rb"))
    end

    it "keeps ActiveRecord, provider I/O, persistence, and nested workflows out" do
      expect(workflow).not_to match(/Game\.where|LineObservation\.where|Bookmaker\.where/)
      expect(workflow).not_to include("CompetitionOdds.acquire")
      expect(workflow).not_to include("PersistLineObservations")
      expect(workflow).not_to include("LineObservation.create")
      expect(workflow).not_to include("ExecuteGameUpdatePolicyWorkflow")
      expect(workflow).not_to include("SynchronizeAdapterWorkflow")
      expect(workflow).to include("retry_strategy :scheduled_cadence")
    end
  end

  context "when scanning LineUpdateJob" do
    subject(:job) { File.read(root.join("app/jobs/jumbotron/line_update_job.rb")) }

    it "uses call_from_job and does not retry locally" do
      expect(job).to include("call_from_job")
      expect(job).not_to include("retry_on")
      expect(job).not_to include("perform_in")
      expect(job).not_to include("GameUpdateJob")
    end
  end

  context "when scanning generic line execution services" do
    subject(:generic) do
      Dir[root.join("app/services/jumbotron/services/adapters/*line*")].map { |path| File.read(path) }.join("\n")
    end

    it "contains no NFL week literals or LineCooldown" do
      expect(generic).not_to match(/\bweek_number\b|\bseasontype\b|\bwild.?card\b/i)
      expect(generic).not_to include("LineCooldown")
      expect(generic).not_to include("OddsCooldown")
      expect(generic).not_to include("the-odds-api.com")
    end
  end

  context "when scanning DesiredSchedules" do
    subject(:source) { File.read(root.join("app/scheduling/jumbotron/scheduling/desired_schedules.rb")) }

    it "does not derive Line schedules from Game schedules" do
      expect(source).to include("LINE_JOB_CLASS_NAME")
      expect(source).to include("GAME_JOB_CLASS_NAME")
      expect(source).not_to include("GameUpdateJob.schedules")
    end
  end

  context "when scanning the Nfl adapter" do
    subject(:nfl) { File.read(root.join("app/adapters/jumbotron/adapters/espn/nfl.rb")) }

    it "does not register competition_odds as an endpoint or read Game policy cadence" do
      expect(nfl).not_to include("endpoint :competition_odds")
      expect(nfl).not_to include("policy(:far_future)")
      expect(nfl).not_to include("policy(:live).cadence")
    end
  end
end
