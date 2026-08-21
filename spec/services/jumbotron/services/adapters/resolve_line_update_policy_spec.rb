# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ResolveLineUpdatePolicy do
  before { Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered? }

  describe ".call" do
    context "when the policy is a line update policy" do
      subject(:result) { described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming_lines") }

      it "resolves the adapter and policy" do
        expect(result).to be_success
        expect(result.data[:adapter]).to eq(Jumbotron::Adapters::Espn::Nfl)
        expect(result.data[:policy].id).to eq(:upcoming_lines)
      end
    end

    context "when the policy is a game update policy" do
      subject(:result) { described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming") }

      it "fails" do
        expect(result).to be_failure
        expect(result.errors.first.code).to eq("invalid_policy_type")
      end
    end

    context "when the adapter is unknown" do
      subject(:result) { described_class.call(adapter_id: "missing", policy_id: "upcoming_lines") }

      it "fails" do
        expect(result).to be_failure
        expect(result.errors.first.code).to eq("unknown_adapter")
      end
    end

    context "when the registry is empty" do
      before { Jumbotron::Adapters::Registry.reset! }

      subject(:result) { described_class.call(adapter_id: "espn_nfl", policy_id: "upcoming_lines") }

      it "loads adapters and resolves the line policy" do
        expect(result).to be_success
        expect(result.data[:adapter]).to eq(Jumbotron::Adapters::Espn::Nfl)
        expect(result.data[:policy].id).to eq(:upcoming_lines)
      end
    end
  end
end
