# frozen_string_literal: true

RSpec.describe Jumbotron::Game do
  describe "league and season association" do
    context "when league and season are present and consistent" do
      subject(:game) { create(:jumbotron_game) }

      it "persists the game" do
        expect(game).to be_persisted
      end

      it "belongs to a league" do
        expect(game.league).to be_a(Jumbotron::League)
      end

      it "belongs to a season" do
        expect(game.season).to be_a(Jumbotron::Season)
      end
    end

    context "when league is missing" do
      let(:season) { create(:jumbotron_season) }

      subject(:game) { build(:jumbotron_game, league: nil, season: season) }

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end

    context "when season is missing" do
      subject(:game) { build(:jumbotron_game, season: nil) }

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end

    context "when season belongs to a different league" do
      let(:league) { create(:jumbotron_league) }
      let(:other_season) { create(:jumbotron_season) }

      subject(:game) { build(:jumbotron_game, league: league, season: other_season) }

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end

    context "when inserting with a nonexistent league_id" do
      let(:season) { create(:jumbotron_season) }
      let(:now) { Time.current }

      subject(:insert_game) do
        described_class.insert!(
          {
            league_id: 0,
            season_id: season.id,
            lifecycle: "scheduled",
            observed_at: now,
            changed_at: now,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_game }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end

    context "when inserting with a nonexistent season_id" do
      let(:league) { create(:jumbotron_league) }
      let(:now) { Time.current }

      subject(:insert_game) do
        described_class.insert!(
          {
            league_id: league.id,
            season_id: 0,
            lifecycle: "scheduled",
            observed_at: now,
            changed_at: now,
            created_at: now,
            updated_at: now
          }
        )
      end

      it "is rejected by the foreign key" do
        expect { insert_game }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end
  end

  describe "season phase association" do
    context "when season phase belongs to a different season" do
      let(:season) { create(:jumbotron_season) }
      let(:other_phase) { create(:jumbotron_season_phase) }

      subject(:game) do
        build(
          :jumbotron_game,
          league: season.league,
          season: season,
          season_phase: other_phase
        )
      end

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end

    context "when season phase is absent" do
      subject(:game) { create(:jumbotron_game, season_phase: nil) }

      it "persists without a season phase" do
        expect(game.season_phase).to be_nil
      end
    end
  end

  describe "venue association" do
    context "when venue is absent" do
      subject(:game) { create(:jumbotron_game, venue: nil) }

      it "persists without a venue" do
        expect(game.venue).to be_nil
      end
    end

    context "when venue is present" do
      let(:venue) { create(:jumbotron_venue) }

      subject(:game) { create(:jumbotron_game, venue: venue) }

      it "references the venue" do
        expect(game.venue).to eq(venue)
      end
    end
  end

  describe "lifecycle" do
    context "when lifecycle is canonical" do
      subject(:game) { create(:jumbotron_game, lifecycle: "completed") }

      it "persists the Jumbotron lifecycle" do
        expect(game.lifecycle).to eq("completed")
      end
    end

    context "when lifecycle is a provider status string" do
      subject(:game) { build(:jumbotron_game, lifecycle: "STATUS_FINAL") }

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end
  end

  describe "schema" do
    it "does not define week_number" do
      expect(described_class.column_names).not_to include("week_number")
    end

    it "does not define espn_week" do
      expect(described_class.column_names).not_to include("espn_week")
    end

    it "does not define away_team_id" do
      expect(described_class.column_names).not_to include("away_team_id")
    end

    it "does not define quarter or time_remaining" do
      expect(described_class.column_names).not_to include("quarter", "time_remaining")
    end
  end

  describe "progress" do
    context "when all progress columns are nil" do
      subject(:game) { create(:jumbotron_game) }

      it "is valid" do
        expect(game).to be_valid
      end

      it "leaves progress_state nil" do
        expect(game.progress_state).to be_nil
      end
    end

    context "when core progress is complete" do
      subject(:game) do
        create(
          :jumbotron_game,
          progress_state: "active",
          progress_segment_kind: "quarter",
          progress_segment_number: 3,
          progress_clock_mode: "remaining",
          progress_clock_seconds: 261,
          progress_clock_display: "4:21"
        )
      end

      it "persists sport-agnostic progress" do
        expect(game).to have_attributes(
          progress_state: "active",
          progress_segment_kind: "quarter",
          progress_segment_number: 3
        )
      end
    end

    context "when only some progress columns are set" do
      subject(:game) { build(:jumbotron_game, progress_state: "active") }

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end

    context "when progress_state is not a generic state" do
      subject(:game) do
        build(
          :jumbotron_game,
          progress_state: "halftime",
          progress_segment_kind: "quarter",
          progress_segment_number: 2
        )
      end

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end

    context "when intermission includes a clock" do
      subject(:game) do
        build(
          :jumbotron_game,
          progress_state: "intermission",
          progress_segment_kind: "quarter",
          progress_segment_number: 2,
          progress_clock_mode: "remaining",
          progress_clock_seconds: 0,
          progress_clock_display: "0:00"
        )
      end

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end

    context "when clock mode is unknown" do
      subject(:game) do
        build(
          :jumbotron_game,
          progress_state: "active",
          progress_segment_kind: "period",
          progress_segment_number: 1,
          progress_clock_mode: "countdown"
        )
      end

      it "is invalid" do
        expect(game).not_to be_valid
      end
    end
  end

  describe "Phase 1 canonical graph" do
    context "when the catalog and graph are persisted" do
      before do
        create(:jumbotron_game_participant, game: game, team: team)
        create(
          :jumbotron_provider_identity,
          target: game,
          object_namespace: "event",
          provider_id: "401772510"
        )
        create(
          :jumbotron_provider_identity,
          target: bookmaker,
          object_namespace: "bookmaker",
          provider_id: "dk-1"
        )
      end

      let(:season) { create(:jumbotron_season) }
      let(:team) { create(:jumbotron_team) }
      let(:bookmaker) { create(:jumbotron_bookmaker) }

      subject(:game) do
        create(
          :jumbotron_game,
          league: season.league,
          season: season,
          season_phase: create(:jumbotron_season_phase, season: season),
          venue: create(:jumbotron_venue)
        )
      end

      it "persists the game" do
        expect(game).to be_persisted
      end

      it "keeps the sport in the catalog" do
        expect(game.league.sport).to be_a(Jumbotron::Sport)
      end

      it "keeps the optional season phase" do
        expect(game.season_phase).to be_a(Jumbotron::SeasonPhase)
      end

      it "references the venue" do
        expect(game.venue).to be_a(Jumbotron::Venue)
      end

      it "associates the team through a participant" do
        expect(game.teams).to contain_exactly(team)
      end

      it "does not require ESPN payloads" do
        expect(game.provider_identities.first.provider_id).not_to eq(game.id.to_s)
      end

      it "keeps bookmaker distinct from the acquisition provider mapping" do
        expect(bookmaker.provider_identities.first.target).to eq(bookmaker)
      end
    end
  end
end
