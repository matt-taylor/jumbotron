# frozen_string_literal: true

RSpec.describe "Slice 2.2.2 architecture" do
  let(:root) { Jumbotron::Engine.root }

  it "removes ApplySyncInput from the active synchronization path" do
    expect(File).not_to exist(
      root.join("app/shared_sequences/jumbotron/shared_sequences/canonical/apply_sync_input.rb")
    )
    expect(defined?(Jumbotron::SharedSequences::Canonical::ApplySyncInput)).to be_nil

    workflow = File.read(root.join("app/workflows/jumbotron/workflows/synchronize_adapter_workflow.rb"))
    expect(workflow).not_to include("ApplySyncInput")
    expect(workflow).not_to include("SharedSequences")
  end

  it "uses the CommandTower workflow transaction primitive" do
    source = File.read(root.join("app/workflows/jumbotron/workflows/synchronize_adapter_workflow.rb"))
    expect(source).to match(/\btransaction\s+do\b/)
    expect(source).to include("fail_transaction!")
    expect(source).not_to include("ActiveRecord::Base.transaction")
  end

  it "keeps Validate and Execute outside the transaction and services as ApplicationService" do
    source = File.read(root.join("app/workflows/jumbotron/workflows/synchronize_adapter_workflow.rb"))
    expect(source).to include("ValidateSyncRequest")
    expect(source).to include("ExecuteEndpoint")
    expect(source).not_to match(/League\.find|adapter\.operation|Clients::Espn/)
    expect(source).not_to match(/ObservationBatch\.|HistoricalChange\.|Game\.create|Team\.create/)

    Dir[root.join("app/services/jumbotron/services/**/*.rb")].each do |path|
      expect(File.read(path)).to include("< CommandTower::Services::ApplicationService")
    end
  end

  it "does not introduce per-policy cadence jobs" do
    expect(Dir[root.join("app/jobs/**/*far_future*")]).to be_empty
  end
end
