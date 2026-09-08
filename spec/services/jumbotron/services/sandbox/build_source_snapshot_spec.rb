# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Sandbox::BuildSourceSnapshot do
  describe ".call" do
    let(:projection) { create(:jumbotron_sandbox_projection) }
    let(:week) do
      create(
        :jumbotron_schedule_group,
        season: projection.source_season,
        season_phase: projection.source_anchor_phase,
        kind: "week",
        number: 1,
        name: "Week 1"
      )
    end
    let(:home_team) { create(:jumbotron_team, name: "Home") }
    let(:away_team) { create(:jumbotron_team, name: "Away") }
    let(:friday_game) do
      create(
        :jumbotron_game,
        league: projection.source_season.league,
        season: projection.source_season,
        season_phase: projection.source_anchor_phase,
        schedule_group: week,
        scheduled_at: Time.utc(2026, 10, 30, 17, 0, 0)
      )
    end
    let(:sunday_game) do
      create(
        :jumbotron_game,
        league: projection.source_season.league,
        season: projection.source_season,
        season_phase: projection.source_anchor_phase,
        schedule_group: week,
        scheduled_at: Time.utc(2026, 11, 1, 18, 0, 0)
      )
    end
    let(:params) do
      {
        projection: projection,
        start_week: 1,
        anchor_day: 2,
        now: Time.utc(2026, 11, 8, 17, 0, 0)
      }
    end

    before do
      create(
        :jumbotron_provider_identity,
        target: home_team,
        provider: "espn",
        object_namespace: "team",
        provider_id: "home-team"
      )
      create(
        :jumbotron_provider_identity,
        target: away_team,
        provider: "espn",
        object_namespace: "team",
        provider_id: "away-team"
      )
      [friday_game, sunday_game].each do |game|
        create(:jumbotron_game_participant, game: game, team: home_team, role: "home")
        create(:jumbotron_game_participant, game: game, team: away_team, role: "away")
      end
    end

    subject(:result) { described_class.call(**params) }

    context "when the anchor day has no game" do
      it "uses the date within the complete group window" do
        expect(result.data[:snapshot]).to have_attributes(
          source_anchor_date: Date.new(2026, 10, 31),
          target_anchor_date: Date.new(2026, 11, 8),
          date_shift_days: 8
        )
      end

      it "preserves Eastern wall-clock time across the DST boundary" do
        projected = result.data[:snapshot].games.find { |game| game.source_game_id == friday_game.id }

        expect(projected.scheduled_at).to eq(Time.utc(2026, 11, 7, 18, 0, 0))
      end
    end

    context "when adjacent source week windows overlap" do
      let(:overlapping_week) do
        create(
          :jumbotron_schedule_group,
          season: projection.source_season,
          season_phase: projection.source_anchor_phase,
          kind: "week",
          number: 2,
          name: "Week 2"
        )
      end
      let(:overlapping_game) do
        create(
          :jumbotron_game,
          league: projection.source_season.league,
          season: projection.source_season,
          season_phase: projection.source_anchor_phase,
          schedule_group: overlapping_week,
          scheduled_at: Time.utc(2026, 10, 31, 18, 0, 0)
        )
      end

      before do
        create(:jumbotron_game_participant, game: overlapping_game, team: home_team, role: "home")
        create(:jumbotron_game_participant, game: overlapping_game, team: away_team, role: "away")
      end

      it "rejects the complete projection before mutation" do
        expect(result.errors.first.code).to eq("sandbox_period_overlap")
      end
    end
  end
end
