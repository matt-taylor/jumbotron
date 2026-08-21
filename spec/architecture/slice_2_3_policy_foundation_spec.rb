# frozen_string_literal: true

RSpec.describe "Slice 2.3 policy foundation architecture" do
  let(:root) { Jumbotron::Engine.root }

  it "does not introduce one-file-per-policy trees or Policy subclasses" do
    expect(Dir[root.join("app/adapters/**/nfl_policies/**/*.rb")]).to be_empty
    expect(Dir[root.join("app/adapters/**/policies/**/*.rb")]).to be_empty
    expect(defined?(Jumbotron::Adapters::Policy)).to be_nil
  end

  it "keeps synchronization policies on Espn::Nfl without I/O" do
    source = File.read(root.join("app/adapters/jumbotron/adapters/espn/nfl.rb"))
    expect(source).to include('adapter_id "espn_nfl"')
    expect(source).to include("policy :far_future")
    expect(source).to include("discovery :full_season")
    expect(source).not_to match(/Rails\.cache|RedisConnection|Clients\.espn|ActiveRecord|Net::HTTP/)
  end

  it "allows cooldown and lease operational primitives" do
    expect(File).to exist(root.join("app/providers/jumbotron/providers/espn/cooldown.rb"))
    expect(File).to exist(root.join("app/synchronization/jumbotron/synchronization/lease.rb"))

    sources = Dir[root.join("app/**/*.rb")].reject { |path| path.include?("/scheduling/") }
                                           .map { |path| File.read(path) }.join("\n")
    expect(sources).not_to match(/\bschedule\(/)
    expect(sources).not_to match(/Sidekiq::Cron|solid_queue_recurring/i)
  end

  it "does not name domain types RedisCooldown or RedisLease" do
    expect(defined?(Jumbotron::Providers::Espn::RedisCooldown)).to be_nil
    expect(defined?(Jumbotron::Synchronization::RedisLease)).to be_nil
  end
end
