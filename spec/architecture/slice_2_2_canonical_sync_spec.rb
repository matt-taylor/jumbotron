# frozen_string_literal: true

RSpec.describe "Slice 2.2 architecture" do
  let(:root) { Jumbotron::Engine.root }

  it "does not define SynchronizeNfl* workflows or services" do
    expect(Dir[root.join("app/**/*synchronize_nfl*")]).to be_empty
    expect(defined?(Jumbotron::Workflows::SynchronizeNflScoreboardWorkflow)).to be_nil
    expect(defined?(Jumbotron::Services::Canonical::SynchronizeGames)).to be_nil
  end

  it "keeps SynchronizeAdapterWorkflow free of ESPN client chains" do
    source = File.read(root.join("app/workflows/jumbotron/workflows/synchronize_adapter_workflow.rb"))
    expect(source).not_to match(/Clients\.espn|Clients::Espn|\.scoreboard|\.teams\.get/)
    expect(source).to include("ExecuteEndpoint")
  end

  it "keeps provider resources free of lifecycle maps and persistence" do
    Dir[root.join("app/providers/jumbotron/providers/espn/resources/*.rb")].each do |path|
      source = File.read(path)
      expect(source).not_to match(/Lifecycle|STATUS_|ApplicationRecord|HistoricalChange|SyncInput/)
    end
  end

  it "does not add espn_id columns to canonical tables" do
    Dir[root.join("db/migrate/*.rb")].each do |path|
      source = File.read(path)
      expect(source).not_to include("espn_id")
    end
  end

  it "does not introduce 2.3 cadence jobs or schedule materialization" do
    sources = Dir[root.join("app/**/*.rb")].reject { |path| path.include?("/scheduling/") }
                                           .map { |path| File.read(path) }.join("\n")
    expect(sources).not_to match(/CadencePolicy|\bschedule\(/)
    expect(sources).not_to match(/Sidekiq::Cron|solid_queue_recurring/i)
  end

  it "registers Espn::Nfl as an activated adapter class reference" do
    expect(Jumbotron::Adapters::Espn::Nfl.registered?).to be(true)
    expect(Jumbotron::Adapters::Registry.registered).to include(Jumbotron::Adapters::Espn::Nfl)
  end
end
