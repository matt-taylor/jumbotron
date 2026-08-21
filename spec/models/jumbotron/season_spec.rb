# frozen_string_literal: true

RSpec.describe Jumbotron::Season do
  describe "league association" do
    context "when a league is present" do
      subject(:season) { create(:jumbotron_season) }

      it "persists the season" do
        expect(season).to be_persisted
      end

      it "belongs to a league" do
        expect(season.league).to be_a(Jumbotron::League)
      end
    end

    context "when league is missing" do
      subject(:season) { build(:jumbotron_season, league: nil) }

      it "is invalid" do
        expect(season).not_to be_valid
      end
    end

    context "when inserting with a nonexistent league_id" do
      let(:now) { Time.current }

      subject(:insert_season) do
        described_class.insert!(
          {
            league_id: 0,
            name: "2026",
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_season }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end
  end

  describe "#season_phases" do
    context "when no phases exist" do
      subject(:season) { create(:jumbotron_season) }

      it "is empty" do
        expect(season.season_phases).to be_empty
      end
    end
  end
end
