# frozen_string_literal: true

module Jumbotron
  module Services
    module Sandbox
      class SeedProjectedGame < CommandTower::Services::ApplicationService
        validate :game, required: true
        validate :observed_at, required: true
        validate :change_set, required: true

        def call
          clear_previous_generation
          return unless persist_lines
          return unless usable_consensus?
          return unless apply_scoreboard

          context.game = game.reload
        end

        private

        def clear_previous_generation
          game.sandbox_game_plan&.destroy!
          game.line_observations.destroy_all
        end

        def persist_lines
          scope = Jumbotron::Adapters::Sandbox::Nfl.line_acquisition_scope_for(game.reload)
          return reject("sandbox line scope is unavailable") if scope.nil?

          result = Jumbotron::Services::Adapters::ExecuteLineAcquisitionScope.call(
            adapter: Jumbotron::Adapters::Sandbox::Nfl,
            acquisition: scope.fetch(:acquisition),
            observed_at: observed_at
          )
          return true if result.success? && result.data[:outcome] == :succeeded

          reject("sandbox line persistence failed")
          false
        end

        def usable_consensus? # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          result = Jumbotron::Services::Canonical::DeriveConsensusLine.call(game: game.reload)
          return reject("sandbox consensus could not be derived") unless result.success?

          lines = Array(result.data[:consensus_lines])
          spread = lines.find { |line| line.market == "spread" && line.outcome == "home" }
          total = lines.find { |line| line.market == "total" && line.outcome == "over" }
          return true if spread && total && spread.line_value == game.sandbox_game_mapping.home_spread &&
                         total.line_value == game.sandbox_game_mapping.total

          reject("sandbox consensus does not match selected line basis")
          false
        end

        def apply_scoreboard # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          scope = Jumbotron::Adapters::Sandbox::Nfl.acquisition_scope_for(game.reload)
          return reject("sandbox scoreboard scope is unavailable") if scope.nil?

          executed = Jumbotron::Services::Adapters::ExecuteEndpoint.call(
            adapter: Jumbotron::Adapters::Sandbox::Nfl,
            endpoint: :scoreboard,
            observed_at: observed_at,
            acquisition: scope.fetch(:acquisition)
          )
          return fail_from(executed) unless executed.success?

          input = executed.data[:sync_input].games.first
          result = Jumbotron::Services::Canonical::UpsertGameGraph.call(
            game_input: input,
            league: game.league,
            observed_at: observed_at,
            change_set: change_set
          )
          return true if result.success?

          fail_from(result)
        end

        def fail_from(result)
          context.fail!(application_error: Array(result.errors).first)
          nil
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
