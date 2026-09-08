# frozen_string_literal: true

RSpec.describe Jumbotron::SandboxGamePlan do
  describe "associations and integrity" do
    context "with a valid selected outcome" do
      subject(:plan) { create(:jumbotron_sandbox_game_plan) }

      it "persists one plan for a game" do
        expect(plan).to be_persisted
      end

      it "is available from the game" do
        expect(plan.game.sandbox_game_plan).to eq(plan)
      end
    end

    context "when a score is negative" do
      subject(:plan) { build(:jumbotron_sandbox_game_plan, home_score: -1) }

      it "is invalid" do
        expect(plan).not_to be_valid
      end
    end

    context "when selected_at is absent" do
      subject(:plan) { build(:jumbotron_sandbox_game_plan, selected_at: nil) }

      it "is invalid" do
        expect(plan).not_to be_valid
      end
    end

    # These inserts intentionally bypass the model to prove database integrity.
    # rubocop:disable Rails/SkipsModelValidations
    context "when the database receives a second plan for one game" do
      before { create(:jumbotron_sandbox_game_plan, game: game) }

      let(:game) { create(:jumbotron_game) }
      let(:now) { Time.current }

      subject(:insert_plan) do
        described_class.insert!(
          {
            game_id: game.id,
            home_score: 27,
            away_score: 24,
            selected_at: now,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the unique index" do
        expect { insert_plan }.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end

    context "when the database receives an unknown game" do
      let(:now) { Time.current }

      subject(:insert_plan) do
        described_class.insert!(
          {
            game_id: 0,
            home_score: 27,
            away_score: 24,
            selected_at: now,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_plan }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    context "when the database receives a null final score" do
      let(:game) { create(:jumbotron_game) }
      let(:now) { Time.current }

      subject(:insert_plan) do
        described_class.insert!(
          {
            game_id: game.id,
            home_score: nil,
            away_score: 24,
            selected_at: now,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the not-null constraint" do
        expect { insert_plan }.to raise_error(ActiveRecord::NotNullViolation)
      end
    end
    # rubocop:enable Rails/SkipsModelValidations
  end

  describe "selected outcome immutability" do
    before { plan.update(home_score: 31) }

    subject(:plan) { create(:jumbotron_sandbox_game_plan, home_score: 24) }

    it "rejects a changed selected score" do
      expect(plan.errors[:base]).to include("selected sandbox outcome is immutable")
    end

    it "retains the selected score" do
      expect(plan.reload.home_score).to eq(24)
    end
  end
end
