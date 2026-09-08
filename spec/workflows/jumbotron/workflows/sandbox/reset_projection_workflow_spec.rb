# frozen_string_literal: true

# The complete transaction proof intentionally names its full cross-model fixture.
# rubocop:disable RSpec/MultipleMemoizedHelpers

RSpec.describe Jumbotron::Workflows::Sandbox::ResetProjectionWorkflow do
  describe ".call" do
    let(:source_sport) { create(:jumbotron_sport, name: "football") }
    let(:source_league) { create(:jumbotron_league, sport: source_sport, name: "nfl") }
    let(:source_season) { create(:jumbotron_season, league: source_league, name: "2026") }
    let(:source_phase) do
      create(:jumbotron_season_phase, season: source_season, name: "regular_season")
    end
    let(:source_week) do
      create(
        :jumbotron_schedule_group,
        season: source_season,
        season_phase: source_phase,
        kind: "week",
        number: 1,
        name: "Week 1"
      )
    end
    let(:source_game) do
      create(
        :jumbotron_game,
        league: source_league,
        season: source_season,
        season_phase: source_phase,
        schedule_group: source_week,
        scheduled_at: Time.utc(2026, 9, 13, 17, 0, 0),
        lifecycle: "scheduled"
      )
    end
    let(:home_team) { create(:jumbotron_team, name: "Home", abbreviation: "HOM") }
    let(:away_team) { create(:jumbotron_team, name: "Away", abbreviation: "AWY") }
    let(:bookmaker) { create(:jumbotron_bookmaker, name: "Source Book") }
    let(:sandbox_sport) { source_sport }
    let(:sandbox_league) do
      create(:jumbotron_league, sport: sandbox_sport, name: "nfl-sandbox")
    end
    let(:sandbox_season) do
      create(:jumbotron_season, league: sandbox_league, name: "apple-review")
    end
    let(:projection) do
      create(
        :jumbotron_sandbox_projection,
        name: "apple-review",
        source_season: source_season,
        source_anchor_phase: source_phase,
        sandbox_season: sandbox_season
      )
    end
    let(:reset_at) { Time.utc(2026, 9, 8, 16, 0, 0) }
    let(:source_observed_at) { Time.utc(2026, 9, 8, 15, 0, 0) }
    let(:source_team_timestamps) do
      [home_team.reload.observed_at, away_team.reload.observed_at]
    end
    let(:params) do
      {
        sandbox: projection.name,
        start_week: 1,
        anchor_day: 1,
        now: reset_at.iso8601
      }
    end

    before do
      create(:jumbotron_game_participant, game: source_game, team: home_team, role: "home", score: 0)
      create(:jumbotron_game_participant, game: source_game, team: away_team, role: "away", score: 0)
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
      create(
        :jumbotron_line_observation,
        game: source_game,
        bookmaker: bookmaker,
        market: "spread",
        outcome: "home",
        line_value: BigDecimal("-4.0"),
        observed_at: source_observed_at,
        changed_at: source_observed_at
      )
      source_team_timestamps
      create(
        :jumbotron_line_observation,
        game: source_game,
        bookmaker: bookmaker,
        market: "total",
        outcome: "over",
        line_value: BigDecimal("45.0"),
        observed_at: source_observed_at,
        changed_at: source_observed_at
      )
    end

    subject(:result) { described_class.call(**params) }

    context "with complete source truth" do
      it "projects one ordinary sandbox game with consensus before its retained outcome" do
        expect(result).to be_success

        mapping = projection.reload.sandbox_game_mappings.sole
        expect(mapping.sandbox_game).to have_attributes(
          scheduled_at: Time.utc(2026, 9, 8, 17, 0, 0),
          lifecycle: "scheduled"
        )
        expect(mapping).to have_attributes(home_spread: BigDecimal("-4.0"), total: BigDecimal("45.0"))
        expect(mapping.sandbox_game.line_observations.count).to eq(4)
        expect(mapping.sandbox_game.sandbox_game_plan).to be_present
      end

      it "preserves mapped game identity and plans on an exact retry" do
        first = described_class.call(**params)
        mapping = projection.reload.sandbox_game_mappings.sole
        identity = [mapping.sandbox_game_id, mapping.sandbox_game.sandbox_game_plan.id]

        second = described_class.call(**params)

        expect(first).to be_success
        expect(second).to be_success
        expect(projection.reload.sandbox_game_mappings.sole).to have_attributes(
          sandbox_game_id: identity.first
        )
        expect(projection.sandbox_game_mappings.sole.sandbox_game.sandbox_game_plan.id).to eq(identity.last)
      end

      it "returns an immutable public reset result" do
        expect(result.payload[:sandbox_reset]).to have_attributes(
          projected_game_count: 1,
          added_game_count: 1,
          source_anchor_date: Date.new(2026, 9, 13),
          target_anchor_date: Date.new(2026, 9, 8),
          date_shift_days: -5
        )
      end

      it "does not mutate source games, lines, teams, or provider identities" do
        expect(result).to be_success
        expect(source_game.reload).to have_attributes(
          scheduled_at: Time.utc(2026, 9, 13, 17, 0, 0),
          lifecycle: "scheduled"
        )
        expect(source_game.line_observations.pluck(:observed_at).uniq).to eq([source_observed_at])
        expect([home_team.reload.observed_at, away_team.reload.observed_at]).to eq(source_team_timestamps)
        expect(Jumbotron::ProviderIdentity.where(provider: "espn", object_namespace: "team").count).to eq(2)
      end
    end

    context "when the anchor day exceeds the source week" do
      let(:params) { super().merge(anchor_day: 2) }

      it "rejects Reset without mutating the sandbox season" do
        expect(result).to be_failure
        expect(projection.sandbox_game_mappings).to be_empty
      end
    end

    context "when a successful projection receives a changed Reset generation" do
      let(:previous_params) { params.merge(now: (reset_at - 1.day).iso8601) }
      let(:successful_reset) { described_class.call(**previous_params) }
      let(:prior_mapping) do
        successful_reset
        projection.reload.sandbox_game_mappings.sole
      end
      let(:prior_game_id) { prior_mapping.sandbox_game_id }
      let(:prior_plan_id) { prior_mapping.sandbox_game.sandbox_game_plan.id }

      before do
        prior_game_id
        prior_plan_id
      end

      it "preserves the mapped game and replaces generation-owned state" do
        expect(result).to be_success

        current = projection.reload.sandbox_game_mappings.sole
        expect(current.sandbox_game_id).to eq(prior_game_id)
        expect(current.sandbox_game.sandbox_game_plan.id).not_to eq(prior_plan_id)
      end
    end

    context "when line persistence fails during a changed Reset" do
      let(:previous_params) { params.merge(now: (reset_at - 1.day).iso8601) }
      let(:successful_reset) { described_class.call(**previous_params) }
      let(:prior_mapping) do
        successful_reset
        projection.reload.sandbox_game_mappings.sole
      end
      let(:prior_plan_id) { prior_mapping.sandbox_game.sandbox_game_plan.id }
      let(:prior_kickoff) { prior_mapping.sandbox_game.scheduled_at }

      before do
        prior_plan_id
        prior_kickoff
        allow(Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.success(data: { outcome: :failed })
        )
      end

      it "rolls back the complete attempted generation" do
        expect(result).to be_failure

        current = projection.reload.sandbox_game_mappings.sole
        expect(current.sandbox_game.reload.scheduled_at).to eq(prior_kickoff)
        expect(current.sandbox_game.sandbox_game_plan.id).to eq(prior_plan_id)
      end
    end

    context "when source truth adds a game" do
      let(:second_week) do
        create(
          :jumbotron_schedule_group,
          season: source_season,
          season_phase: source_phase,
          kind: "week",
          number: 2,
          name: "Week 2"
        )
      end
      let(:second_game) do
        create(
          :jumbotron_game,
          league: source_league,
          season: source_season,
          season_phase: source_phase,
          schedule_group: second_week,
          scheduled_at: Time.utc(2026, 9, 20, 17, 0, 0)
        )
      end
      let(:first_reset) { described_class.call(**params) }
      let(:first_sandbox_game_id) do
        first_reset
        projection.reload.sandbox_game_mappings.sole.sandbox_game_id
      end

      before do
        first_sandbox_game_id
        create(:jumbotron_game_participant, game: second_game, team: home_team, role: "home")
        create(:jumbotron_game_participant, game: second_game, team: away_team, role: "away")
      end

      it "adds the new mapping without replacing the existing game" do
        expect(result).to be_success
        expect(projection.reload.sandbox_game_mappings.count).to eq(2)
        expect(projection.sandbox_game_mappings.find_by!(source_game: source_game).sandbox_game_id)
          .to eq(first_sandbox_game_id)
        expect(result.payload[:sandbox_reset].added_game_count).to eq(1)
      end
    end

    context "when source truth removes a previously mapped game" do
      let(:second_week) do
        create(
          :jumbotron_schedule_group,
          season: source_season,
          season_phase: source_phase,
          kind: "week",
          number: 2,
          name: "Week 2"
        )
      end
      let(:second_game) do
        create(
          :jumbotron_game,
          league: source_league,
          season: source_season,
          season_phase: source_phase,
          schedule_group: second_week,
          scheduled_at: Time.utc(2026, 9, 20, 17, 0, 0)
        )
      end
      let(:archived_season) { create(:jumbotron_season, league: source_league, name: "archived") }
      let(:archived_phase) do
        create(:jumbotron_season_phase, season: archived_season, name: "regular_season")
      end
      let(:archived_week) do
        create(
          :jumbotron_schedule_group,
          season: archived_season,
          season_phase: archived_phase,
          kind: "week",
          number: 2,
          name: "Week 2"
        )
      end
      let(:initial_reset) { described_class.call(**params) }
      let(:removed_sandbox_game_id) do
        initial_reset
        projection.reload.sandbox_game_mappings.find_by!(source_game: second_game).sandbox_game_id
      end

      before do
        create(:jumbotron_game_participant, game: second_game, team: home_team, role: "home")
        create(:jumbotron_game_participant, game: second_game, team: away_team, role: "away")
        removed_sandbox_game_id
        second_game.update!(
          season: archived_season,
          season_phase: archived_phase,
          schedule_group: archived_week
        )
      end

      it "removes only the stale mapped sandbox graph" do
        expect(result).to be_success
        expect(projection.reload.sandbox_game_mappings.count).to eq(1)
        expect(projection.sandbox_season.schedule_groups.count).to eq(1)
        expect(Jumbotron::Game.exists?(removed_sandbox_game_id)).to be(false)
        expect(result.payload[:sandbox_reset].removed_game_count).to eq(1)
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
