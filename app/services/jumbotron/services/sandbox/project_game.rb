# frozen_string_literal: true

module Jumbotron
  module Services
    module Sandbox
      class ProjectGame < CommandTower::Services::ApplicationService
        validate :projection, required: true
        validate :projected_game, required: true
        validate :observed_at, required: true
        validate :change_set, required: true

        def call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          executed = Jumbotron::Services::Adapters::ExecuteEndpoint.call(
            adapter: Jumbotron::Adapters::Sandbox::Nfl,
            endpoint: :projection,
            observed_at: observed_at,
            acquisition: acquisition
          )
          return fail_from(executed) unless executed.success?

          input = Array(executed.data[:sync_input]&.games).one? ? executed.data[:sync_input].games.first : nil
          return reject("projection endpoint did not return one game") if input.nil?

          graph = Jumbotron::Services::Canonical::UpsertGameGraph.call(
            game_input: input,
            league: projection.sandbox_season.league,
            observed_at: observed_at,
            change_set: change_set
          )
          return fail_from(graph) unless graph.success?

          mapping = projection.sandbox_game_mappings.find_or_initialize_by(
            source_game_id: projected_game.source_game_id
          )
          context.created = mapping.new_record?
          mapping.assign_attributes(
            sandbox_game: graph.data[:game],
            home_spread: projected_game.home_spread,
            total: projected_game.total,
            line_fingerprint: projected_game.line_fingerprint
          )
          mapping.save!
          context.mapping = mapping
          context.game = graph.data[:game]
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          reject(e.message)
        end

        private

        def acquisition
          projected_game.to_h.merge(
            scheduled_at: projected_game.scheduled_at.iso8601,
            home: projected_game.home.to_h,
            away: projected_game.away.to_h
          )
        end

        def fail_from(result)
          context.fail!(application_error: Array(result.errors).first)
        end

        def reject(message)
          context.fail!(
            application_error: Jumbotron::Errors::Sandbox::ProjectionRejectedError.new(
              details: { code: "sandbox_projection_incomplete", message: message }
            )
          )
        end
      end
    end
  end
end
