# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ResolveGameUpdatePolicy do
  before { Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered? }

  it "resolves a registered adapter and update policy" do
    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming")

    expect(result).to be_success
    expect(result.data[:adapter]).to eq(Jumbotron::Adapters::Espn::Nfl)
    expect(result.data[:policy].id).to eq(:upcoming)
  end

  it "loads adapter classes when the registry is empty (lazy worker path)" do
    Jumbotron::Adapters::Registry.reset!

    result = described_class.call(adapter_id: "espn_nfl", policy_id: "live")

    expect(result).to be_success
    expect(result.data[:adapter]).to eq(Jumbotron::Adapters::Espn::Nfl)
    expect(Jumbotron::Adapters::Registry.find("espn_nfl")).to eq(Jumbotron::Adapters::Espn::Nfl)
  end

  it "fails for an unknown adapter" do
    result = described_class.call(adapter_id: "missing", policy_id: "upcoming")

    expect(result).to be_failure
    expect(result.errors.first.code).to eq("unknown_adapter")
  end

  it "fails for an unknown policy" do
    result = described_class.call(adapter_id: "espn_nfl", policy_id: "not_a_policy")

    expect(result).to be_failure
    expect(result.errors.first.code).to eq("unknown_policy")
  end

  it "does not resolve a line-update policy" do
    result = described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming_lines")

    expect(result).to be_failure
    expect(result.errors.first.code).to eq("invalid_policy_type")
  end

  it "does not resolve an unregistered adapter class" do
    orphan = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecUnregisteredPolicy"
      end

      adapter_id "ghost_nfl"
      provider :espn
      sport "football"
      league "ghost"
    end
    stub_const("Jumbotron::Adapters::SpecUnregisteredPolicy", orphan)

    result = described_class.call(adapter_id: "ghost_nfl", policy_id: "upcoming")
    expect(result).to be_failure
    expect(result.errors.first.code).to eq("unknown_adapter")
  end
end
