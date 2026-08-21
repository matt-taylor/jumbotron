# frozen_string_literal: true

RSpec.describe Jumbotron::ProviderIdentity do
  describe "canonical mapping" do
    context "when mapping an unrelated provider id onto a Sport" do
      let(:sport) { create(:jumbotron_sport) }

      subject(:provider_identity) do
        create(
          :jumbotron_provider_identity,
          target: sport,
          provider: "espn",
          object_namespace: "sport",
          provider_id: "401772510"
        )
      end

      it "persists separately from the canonical record" do
        expect(provider_identity).to be_persisted
      end

      it "keeps the provider id independent of the canonical primary key" do
        expect(provider_identity.provider_id).not_to eq(sport.id.to_s)
      end

      it "points at the canonical target" do
        expect(provider_identity.target).to eq(sport)
      end
    end

    context "when mapping an unrelated provider id onto a Team" do
      let(:team) { create(:jumbotron_team) }

      subject(:provider_identity) do
        create(
          :jumbotron_provider_identity,
          target: team,
          object_namespace: "team",
          provider_id: "kc-chiefs"
        )
      end

      it "keeps the provider id independent of the canonical primary key" do
        expect(provider_identity.provider_id).not_to eq(team.id.to_s)
      end
    end

    context "when mapping an unrelated provider id onto a Game" do
      let(:game) { create(:jumbotron_game) }

      subject(:provider_identity) do
        create(
          :jumbotron_provider_identity,
          target: game,
          object_namespace: "event",
          provider_id: "401772510"
        )
      end

      it "points at the canonical game" do
        expect(provider_identity.target).to eq(game)
      end
    end
  end

  describe "provider normalization" do
    context "when provider has mixed case and surrounding whitespace" do
      subject(:provider_identity) do
        create(:jumbotron_provider_identity, provider: " ESPN ")
      end

      it "stores a lowercase provider" do
        expect(provider_identity.provider).to eq("espn")
      end
    end
  end

  describe "uniqueness" do
    let(:sport) { create(:jumbotron_sport) }

    context "when the provider triple already exists" do
      before do
        create(
          :jumbotron_provider_identity,
          target: sport,
          provider: "espn",
          object_namespace: "sport",
          provider_id: "dup-1"
        )
      end

      let(:other_sport) { create(:jumbotron_sport) }

      subject(:duplicate) do
        build(
          :jumbotron_provider_identity,
          target: other_sport,
          provider: "espn",
          object_namespace: "sport",
          provider_id: "dup-1"
        )
      end

      it "is invalid" do
        expect(duplicate).not_to be_valid
      end
    end

    context "when inserting a duplicate provider triple" do
      before do
        create(
          :jumbotron_provider_identity,
          target: sport,
          provider: "espn",
          object_namespace: "sport",
          provider_id: "dup-1"
        )
      end

      let(:other_sport) { create(:jumbotron_sport) }
      let(:now) { Time.current }

      subject(:insert_duplicate) do
        described_class.insert!(
          {
            provider: "espn",
            object_namespace: "sport",
            provider_id: "dup-1",
            target_type: "Jumbotron::Sport",
            target_id: other_sport.id,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the unique index" do
        expect { insert_duplicate }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end
end
