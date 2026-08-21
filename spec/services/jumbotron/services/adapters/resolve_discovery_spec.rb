# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ResolveDiscovery do
  before { Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered? }

  it "resolves a registered adapter and declared discovery" do
    result = described_class.call(adapter_id: "espn_nfl", discovery_id: "full_season")

    expect(result).to be_success
    expect(result.data[:adapter]).to eq(Jumbotron::Adapters::Espn::Nfl)
    expect(result.data[:definition].id).to eq(:full_season)
  end

  it "loads adapter classes when the registry is empty (lazy worker path)" do
    Jumbotron::Adapters::Registry.reset!

    result = described_class.call(adapter_id: "espn_nfl", discovery_id: "full_season")

    expect(result).to be_success
    expect(result.data[:adapter]).to eq(Jumbotron::Adapters::Espn::Nfl)
  end

  it "fails for an unknown adapter" do
    result = described_class.call(adapter_id: "missing", discovery_id: "full_season")

    expect(result).to be_failure
    expect(result.errors.first.code).to eq("unknown_adapter")
  end

  it "fails for an unknown discovery" do
    result = described_class.call(adapter_id: "espn_nfl", discovery_id: "not_a_discovery")

    expect(result).to be_failure
    expect(result.errors.first.code).to eq("unknown_discovery")
  end

  it "does not resolve an unregistered adapter class" do
    orphan = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecUnregisteredDiscovery"
      end

      adapter_id "ghost_discovery"
      provider :espn
      sport "football"
      league "ghost"
      discovery :full_season, endpoint: :scoreboard
    end
    stub_const("Jumbotron::Adapters::SpecUnregisteredDiscovery", orphan)

    result = described_class.call(adapter_id: "ghost_discovery", discovery_id: "full_season")
    expect(result).to be_failure
    expect(result.errors.first.code).to eq("unknown_adapter")
  end
end
