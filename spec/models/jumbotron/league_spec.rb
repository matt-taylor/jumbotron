# frozen_string_literal: true

RSpec.describe Jumbotron::League do
  describe "sport association" do
    context "when a sport is present" do
      subject(:league) { create(:jumbotron_league) }

      it "persists the league" do
        expect(league).to be_persisted
      end

      it "belongs to a sport" do
        expect(league.sport).to be_a(Jumbotron::Sport)
      end
    end

    context "when sport is missing" do
      subject(:league) { build(:jumbotron_league, sport: nil) }

      it "is invalid" do
        expect(league).not_to be_valid
      end
    end

    context "when inserting with a nonexistent sport_id" do
      let(:now) { Time.current }

      subject(:insert_league) do
        described_class.insert!(
          {
            sport_id: 0,
            name: "NFL",
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_league }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end
  end
end
