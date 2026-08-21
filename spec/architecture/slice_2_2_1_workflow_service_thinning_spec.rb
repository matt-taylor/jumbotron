# frozen_string_literal: true

RSpec.describe "Slice 2.2.1 architecture" do
  let(:root) { Jumbotron::Engine.root }

  it "deletes Canonical::Synchronize" do
    expect(File).not_to exist(root.join("app/services/jumbotron/services/canonical/synchronize.rb"))
    expect(defined?(Jumbotron::Services::Canonical::Synchronize)).to be_nil
  end

  it "requires Jumbotron services to inherit ApplicationService" do
    Dir[root.join("app/services/jumbotron/services/**/*.rb")].each do |path|
      source = File.read(path)
      expect(source).not_to match(/Result\s*=\s*Struct\.new/)
      expect(source).to include("< CommandTower::Services::ApplicationService")
    end
  end

  it "keeps SynchronizeAdapterWorkflow as Validate → Execute → transactional apply orchestration" do
    source = File.read(root.join("app/workflows/jumbotron/workflows/synchronize_adapter_workflow.rb"))
    expect(source).to include("ValidateSyncRequest")
    expect(source).to include("ExecuteEndpoint")
    expect(source).to match(/\btransaction\s+do\b/)
    expect(source).not_to match(/League\.find|adapter\.operation|Clients::Espn|ObservationBatch|HistoricalChange|ActiveRecord::Base\.transaction/)
  end

  it "does not introduce per-policy cadence jobs" do
    expect(Dir[root.join("app/jobs/**/*far_future*")]).to be_empty
  end
end
