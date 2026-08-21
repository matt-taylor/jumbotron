# frozen_string_literal: true

RSpec.describe "Slice 3.2 line observation ingest architecture" do
  let(:root) { Jumbotron::Engine.root }

  context "when scanning the competition odds helper" do
    subject(:adapter_source) do
      File.read(root.join("app/adapters/jumbotron/adapters/espn/nfl_helpers/competition_odds.rb"))
    end

    it "keeps adapter translation free of ActiveRecord" do
      expect(adapter_source).not_to include("ApplicationRecord")
      expect(adapter_source).not_to include("ActiveRecord")
      expect(adapter_source).not_to include(".create!")
      expect(adapter_source).not_to include(".update!")
      expect(adapter_source).not_to include(".find_by")
      expect(adapter_source).not_to include("Bookmaker.lock")
    end
  end

  context "when scanning canonical persist services" do
    let(:persist_source) do
      File.read(root.join("app/services/jumbotron/services/canonical/persist_line_observations.rb"))
    end
    let(:ensure_source) do
      File.read(root.join("app/services/jumbotron/services/canonical/ensure_bookmaker.rb"))
    end
    let(:canonical_persist_sources) { persist_source + ensure_source }

    it "keeps generic persistence free of ESPN and NFL knowledge" do
      expect(canonical_persist_sources).not_to match(/\bESPN\b/)
      expect(canonical_persist_sources).not_to match(/\blisted_provider\b/)
      expect(canonical_persist_sources).not_to match(/\bhome_team_odds\b/)
      expect(canonical_persist_sources).not_to match(/\baway_team_odds\b/)
      expect(canonical_persist_sources).not_to match(/\bnfl\b/i)
      expect(canonical_persist_sources).not_to match(/\bfootball\b/)
    end

    it "keeps provider acquisition and Jumbotron transaction wrappers out of persist" do
      expect(persist_source).not_to include("CompetitionOdds.acquire")
      expect(persist_source).to include("transaction")
      expect(persist_source).to include("fail_transaction!")
      expect(persist_source).not_to include("ApplicationRecord.transaction")
      expect(persist_source).not_to include("ActiveRecord::Base.transaction")
    end
  end

  context "when scanning for ingest entry points" do
    it "does not persist lines from a workflow" do
      workflow_sources = Dir[root.join("app/workflows/**/*.rb")].map { |path| File.read(path) }.join("\n")
      expect(workflow_sources).not_to include("PersistLineObservations")
      expect(workflow_sources).not_to include("LineObservation.create")
    end
  end

  context "when scanning for current-line and consensus models" do
    it "does not persist Current Line or Consensus" do
      expect(defined?(Jumbotron::CurrentLine)).to be_nil
      expect(defined?(Jumbotron::ConsensusLine)).to be_nil
      expect(defined?(Jumbotron::Consensus)).to be_nil
      expect(Dir[root.join("db/migrate/*current_line*")]).to be_empty
      expect(Dir[root.join("db/migrate/*consensus*")]).to be_empty
    end
  end

  context "when scanning application sources" do
    subject(:app_sources) { Dir[root.join("app/**/*.rb")].map { |path| File.read(path) }.join("\n") }

    it "does not introduce The Odds API or ingest workflows" do
      expect(app_sources).not_to include("the-odds-api.com")
      expect(app_sources).not_to include("OddsApi::")
      expect(app_sources).not_to include("api.draftkings")
      expect(app_sources).not_to include("IngestLinesWorkflow")
      expect(app_sources).not_to include("PersistLinesWorkflow")
      expect(app_sources).not_to include("SynchronizeLinesWorkflow")
    end
  end

  context "when scanning the Nfl adapter" do
    subject(:nfl_adapter_source) { File.read(root.join("app/adapters/jumbotron/adapters/espn/nfl.rb")) }

    it "does not register competition odds as an Nfl adapter endpoint" do
      expect(nfl_adapter_source).not_to include("competition_odds")
    end

    it "places odds translation on the existing Nfl helper tree" do
      expect(File).to exist(root.join("app/adapters/jumbotron/adapters/espn/nfl_helpers/competition_odds.rb"))
      expect(Dir[root.join("app/adapters/jumbotron/adapters/**/*odds_adapter*")]).to be_empty
    end
  end
end
