# frozen_string_literal: true

RSpec.describe "Slice 2.3.1 full-season discovery contract" do
  let(:root) { Jumbotron::Engine.root }

  it "keeps ESPN request enumeration off the NFL adapter" do
    source = File.read(root.join("app/adapters/jumbotron/adapters/espn/nfl.rb"))
    expect(source).not_to include("PRESEASON_WEEKS")
    expect(source).not_to include("REGULAR_WEEKS")
    expect(source).not_to include("POSTSEASON_WEEKS")
    expect(source).not_to include("acquisition_scopes")
    expect(source).to include("discovery :full_season, endpoint: :scoreboard")
    expect(Jumbotron::Adapters::Espn::Nfl.const_defined?(:PRESEASON_WEEKS)).to be(false)
  end

  it "places full-season expansion on the ESPN Scoreboard resource" do
    source = File.read(root.join("app/providers/jumbotron/providers/espn/resources/scoreboard.rb"))
    expect(source).to include("def self.acquire_full_season")
    expect(source).to include("def self.expand_full_season")
    expect(source).not_to include("observed_at")
    expect(source).not_to include("ActiveRecord")
  end

  it "does not introduce schedulers in discovery resources" do
    expect(File).to exist(root.join("app/jobs/jumbotron/discovery_job.rb"))
    expect(defined?(Jumbotron::DiscoveryJob)).to eq("constant")
    sources = Dir[root.join("app/**/*.rb")].reject { |path| path.include?("/scheduling/") }
                                           .map { |path| File.read(path) }.join("\n")
    expect(sources).not_to match(/\bschedule\(/)
    expect(sources).not_to match(/Sidekiq::Cron|solid_queue_recurring/i)
  end
end
