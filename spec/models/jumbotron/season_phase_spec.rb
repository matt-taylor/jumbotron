# frozen_string_literal: true

RSpec.describe Jumbotron::SeasonPhase do
  describe "season association" do
    context "when a season is present" do
      subject(:season_phase) { create(:jumbotron_season_phase) }

      it "persists the phase" do
        expect(season_phase).to be_persisted
      end

      it "belongs to a season" do
        expect(season_phase.season).to be_a(Jumbotron::Season)
      end
    end

    context "when season is missing" do
      subject(:season_phase) { build(:jumbotron_season_phase, season: nil) }

      it "is invalid" do
        expect(season_phase).not_to be_valid
      end
    end

    context "when inserting with a nonexistent season_id" do
      let(:now) { Time.current }

      subject(:insert_phase) do
        described_class.insert!(
          {
            season_id: 0,
            name: "Regular Season",
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_phase }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end
  end
end
