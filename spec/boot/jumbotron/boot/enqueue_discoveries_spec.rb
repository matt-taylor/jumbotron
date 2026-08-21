# frozen_string_literal: true

RSpec.describe Jumbotron::Boot::EnqueueDiscoveries do
  before { Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered? }

  it "is not eligible in the test environment" do
    expect(described_class.eligible?).to be(false)
  end

  it "enqueues DiscoveryJob for registered adapter discoveries without Game-update policies" do
    described_class.enqueue!

    expect(Jumbotron::DiscoveryJob).to have_been_enqueued.with(
      adapter_id: "espn_nfl",
      discovery_id: "full_season",
      continuation_attempt: 1
    )
    expect(Jumbotron::GameUpdateJob).not_to have_been_enqueued
  end

  it "includes a second adapter discovery without Engine changes" do
    extra = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecSecondDiscovery"
      end

      adapter_id "spec_other"
      provider :espn
      sport "football"
      league "other"
      discovery :full_season, endpoint: :scoreboard
    end
    stub_const("Jumbotron::Adapters::SpecSecondDiscovery", extra)
    extra.register!

    described_class.enqueue!

    expect(Jumbotron::DiscoveryJob).to have_been_enqueued.with(
      hash_including(adapter_id: "spec_other", discovery_id: "full_season")
    )
  ensure
    Jumbotron::Adapters::Registry.reset! if Jumbotron::Adapters::Registry.respond_to?(:reset!)
    Jumbotron::Adapters::Espn::Nfl.register!
  end
end
