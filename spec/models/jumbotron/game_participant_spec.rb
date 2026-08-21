# frozen_string_literal: true

RSpec.describe Jumbotron::GameParticipant do
  describe "game and team association" do
    context "when game and team are present" do
      subject(:participant) { create(:jumbotron_game_participant, role: "home", score: 24, result: "win") }

      it "persists the participant" do
        expect(participant).to be_persisted
      end

      it "belongs to a game" do
        expect(participant.game).to be_a(Jumbotron::Game)
      end

      it "belongs to a team" do
        expect(participant.team).to be_a(Jumbotron::Team)
      end

      it "stores role on the participant" do
        expect(participant.role).to eq("home")
      end

      it "stores score on the participant" do
        expect(participant.score).to eq(24)
      end

      it "stores result on the participant" do
        expect(participant.result).to eq("win")
      end
    end

    context "when game is missing" do
      subject(:participant) { build(:jumbotron_game_participant, game: nil) }

      it "is invalid" do
        expect(participant).not_to be_valid
      end
    end

    context "when team is missing" do
      subject(:participant) { build(:jumbotron_game_participant, team: nil) }

      it "is invalid" do
        expect(participant).not_to be_valid
      end
    end

    context "when inserting with a nonexistent game_id" do
      let(:team) { create(:jumbotron_team) }
      let(:now) { Time.current }

      subject(:insert_participant) do
        described_class.insert!(
          {
            game_id: 0,
            team_id: team.id,
            observed_at: now,
            changed_at: now,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_participant }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    context "when inserting with a nonexistent team_id" do
      let(:game) { create(:jumbotron_game) }
      let(:now) { Time.current }

      subject(:insert_participant) do
        described_class.insert!(
          {
            game_id: game.id,
            team_id: 0,
            observed_at: now,
            changed_at: now,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_participant }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end
  end

  describe "uniqueness" do
    let(:game) { create(:jumbotron_game) }
    let(:team) { create(:jumbotron_team) }

    context "when the game and team already participate" do
      before { create(:jumbotron_game_participant, game: game, team: team) }

      subject(:duplicate) { build(:jumbotron_game_participant, game: game, team: team) }

      it "is invalid" do
        expect(duplicate).not_to be_valid
      end
    end

    context "when inserting a duplicate game and team" do
      let(:now) { Time.current }

      before { create(:jumbotron_game_participant, game: game, team: team) }

      subject(:insert_duplicate) do
        described_class.insert!(
          {
            game_id: game.id,
            team_id: team.id,
            observed_at: now,
            changed_at: now,
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
