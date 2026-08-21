# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::EnsureBookmaker do
  describe ".call" do
    let(:now) { Time.utc(2026, 8, 13, 12, 0, 0) }
    let(:name) { "Draft Kings" }
    let(:identity) do
      Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "bookmaker", id: "100")
    end

    context "when the same ESPN provider id is ingested twice" do
      before { described_class.call(identity:, name:, observed_at: now) }

      subject(:result) do
        described_class.call(identity:, name:, observed_at: now + 1.minute)
      end

      it "is successful" do
        expect(result).to be_success
      end

      it "reuses one Bookmaker" do
        expect(result.data[:bookmaker].id).to eq(Jumbotron::Bookmaker.first.id)
        expect(Jumbotron::Bookmaker.count).to eq(1)
      end

      it "reuses one bookmaker provider identity" do
        expect(Jumbotron::ProviderIdentity.where(object_namespace: "bookmaker").count).to eq(1)
      end
    end

    context "when ESPN changes the bookmaker display name" do
      before { described_class.call(identity:, name: "Draft Kings", observed_at: now) }

      subject(:result) do
        described_class.call(identity:, name: "DraftKings", observed_at: now + 1.minute)
      end

      it "keeps a single Bookmaker" do
        expect(Jumbotron::Bookmaker.count).to eq(1)
      end

      it "updates the canonical name" do
        expect(result.data[:bookmaker].name).to eq("DraftKings")
      end

      it "advances changed_at" do
        expect(result.data[:bookmaker].changed_at).to eq(now + 1.minute)
      end
    end

    context "when two ESPN ids share a display name" do
      let(:other_identity) do
        Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "bookmaker", id: "200")
      end

      before { described_class.call(identity:, name:, observed_at: now) }

      subject(:result) do
        described_class.call(identity: other_identity, name:, observed_at: now)
      end

      it "creates a second Bookmaker" do
        expect(result.data[:bookmaker].id).not_to eq(Jumbotron::Bookmaker.order(:id).first.id)
        expect(Jumbotron::Bookmaker.count).to eq(2)
      end
    end
  end
end
