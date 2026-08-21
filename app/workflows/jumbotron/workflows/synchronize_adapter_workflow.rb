# frozen_string_literal: true

module Jumbotron
  module Workflows
    class SynchronizeAdapterWorkflow < CommandTower::Workflows::ApplicationWorkflow
      retry_strategy :none

      def call(adapter:, endpoint:, league_id:, observed_at: nil, acquisition: {})
        observed_at ||= Time.current

        validated = Jumbotron::Services::Adapters::ValidateSyncRequest.call(
          adapter: adapter,
          endpoint: endpoint,
          league_id: league_id
        )
        return map_service_failure(validated, failure_class: "validation") unless validated.success?

        executed = Jumbotron::Services::Adapters::ExecuteEndpoint.call(
          adapter: adapter,
          endpoint: endpoint,
          observed_at: observed_at,
          acquisition: acquisition || {}
        )
        return map_execute_failure(executed) unless executed.success?

        transaction do
          apply_canonical_sync!(
            input: executed.data[:sync_input],
            league: validated.data[:league],
            provider: adapter.provider,
            adapter_scope: "#{adapter.provider}:#{adapter.sport}:#{adapter.league}:#{endpoint}"
          )
        end
      end

      private

      def apply_canonical_sync!(input:, league:, provider:, adapter_scope:)
        unless input.is_a?(Jumbotron::Canonical::SyncInput)
          fail_transaction!(
            map_service_failure(
              CommandTower::Services::ServiceResult.failure(
                errors: [Jumbotron::Errors::Canonical::InvalidSyncInputError.new]
              ),
              failure_class: "mutation"
            )
          )
        end

        change_set = Jumbotron::Canonical::ChangeSet.new
        teams = []

        games = input.games.map do |game_input|
          sync_one_game!(game_input, league, input.observed_at, change_set)
        end

        input.teams.each do |team_input|
          team_result = Services::Canonical::UpsertTeam.call(
            team_input: team_input,
            observed_at: input.observed_at,
            change_set: change_set
          )
          fail_on_service_failure!(team_result)
          teams << team_result.data[:team]
        end

        evidence = Services::Canonical::RecordObservationEvidence.call(
          change_set: change_set,
          provider: provider,
          adapter_scope: adapter_scope,
          observed_at: input.observed_at
        )
        fail_on_service_failure!(evidence)

        success(
          payload: {
            games: games,
            teams: teams,
            observation_batch_id: evidence.data[:observation_batch_id],
            historical_change_count: evidence.data[:historical_change_count]
          },
          http_status: :ok
        )
      rescue ActiveRecord::RecordInvalid => e
        fail_transaction!(
          failure(
            errors: [
              Jumbotron::Errors::Canonical::MutationFailedError.new(details: { message: e.message })
            ],
            http_status: :unprocessable_entity,
            meta: { failure_class: "mutation" }
          )
        )
      end

      def sync_one_game!(game_input, league, observed_at, change_set)
        season_result = Services::Canonical::EnsureSeason.call(
          league: league,
          year: game_input.season_year
        )
        fail_on_service_failure!(season_result)

        phase_result = Services::Canonical::EnsureSeasonPhase.call(
          season: season_result.data[:season],
          phase_key: game_input.season_phase_key
        )
        fail_on_service_failure!(phase_result)

        group_result = Services::Canonical::EnsureScheduleGroup.call(
          season: season_result.data[:season],
          season_phase: phase_result.data[:season_phase],
          schedule_group_input: game_input.schedule_group
        )
        fail_on_service_failure!(group_result)

        venue_result = Services::Canonical::UpsertVenue.call(
          venue_input: game_input.venue,
          observed_at: observed_at,
          change_set: change_set
        )
        fail_on_service_failure!(venue_result)

        game_result = Services::Canonical::UpsertGame.call(
          game_input: game_input,
          league: league,
          season: season_result.data[:season],
          season_phase: phase_result.data[:season_phase],
          schedule_group: group_result.data[:schedule_group],
          venue: venue_result.data[:venue],
          observed_at: observed_at,
          change_set: change_set
        )
        fail_on_service_failure!(game_result)

        game = game_result.data[:game]

        attach = Services::Canonical::AttachProviderIdentities.call(
          target: game,
          refs: game_input.provider_identities
        )
        fail_on_service_failure!(attach)

        game_input.participants.each do |participant_input|
          gp_result = Services::Canonical::UpsertGameParticipant.call(
            game: game,
            participant_input: participant_input,
            observed_at: observed_at,
            change_set: change_set
          )
          fail_on_service_failure!(gp_result)
        end

        game
      end

      def fail_on_service_failure!(service_result)
        return if service_result.success?

        fail_transaction!(map_service_failure(service_result, failure_class: "mutation"))
      end

      def map_execute_failure(result)
        error = Array(result.errors).first
        code = error.respond_to?(:code) ? error.code : "normalization_failed"
        failure(
          errors: [{ code: code, message: error.respond_to?(:message) ? error.message : error.to_s }],
          http_status: code == "acquisition_failed" ? :bad_gateway : :unprocessable_entity,
          meta: { failure_class: code == "acquisition_failed" ? "acquisition" : "normalization" }
        )
      end

      def map_service_failure(result, failure_class:)
        error = Array(result.errors).first
        code = error.respond_to?(:code) ? error.code : "#{failure_class}_failed"
        failure(
          errors: [{ code: code, message: error.respond_to?(:message) ? error.message : error.to_s }],
          http_status: :unprocessable_entity,
          meta: { failure_class: failure_class }
        )
      end
    end
  end
end
