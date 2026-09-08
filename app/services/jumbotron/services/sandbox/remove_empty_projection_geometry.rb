# frozen_string_literal: true

module Jumbotron
  module Services
    module Sandbox
      class RemoveEmptyProjectionGeometry < CommandTower::Services::ApplicationService
        validate :projection, required: true

        def call
          remove_empty_groups
          remove_empty_phases
        rescue ActiveRecord::ActiveRecordError => e
          reject(e)
        end

        private

        def reject(error)
          context.fail!(
            application_error: Jumbotron::Errors::Sandbox::ProjectionRejectedError.new(
              details: {
                code: "sandbox_projection_incomplete",
                message: "stale sandbox schedule geometry could not be removed",
                failure: error.class.name
              }
            )
          )
        end

        def remove_empty_groups
          projection.sandbox_season.schedule_groups
                    .left_outer_joins(:games)
                    .where(jumbotron_games: { id: nil })
                    .destroy_all
        end

        def remove_empty_phases
          projection.sandbox_season.season_phases
                    .left_outer_joins(:games, :schedule_groups)
                    .where(jumbotron_games: { id: nil }, jumbotron_schedule_groups: { id: nil })
                    .destroy_all
        end
      end
    end
  end
end
