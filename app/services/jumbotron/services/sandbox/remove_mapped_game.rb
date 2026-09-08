# frozen_string_literal: true

module Jumbotron
  module Services
    module Sandbox
      class RemoveMappedGame < CommandTower::Services::ApplicationService
        validate :mapping, required: true

        def call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          game = mapping.sandbox_game
          mapping.destroy!
          game.reload
          Jumbotron::SandboxGamePlan.find_by(game_id: game.id)&.destroy!
          game.line_observations.destroy_all
          game.game_participants.destroy_all
          game.provider_identities.destroy_all
          game.destroy!
          context.removed_game_id = game.id
        rescue ActiveRecord::ActiveRecordError => e
          context.fail!(
            application_error: Jumbotron::Errors::Sandbox::ProjectionRejectedError.new(
              details: { code: "sandbox_projection_incomplete", message: e.message }
            )
          )
        end
      end
    end
  end
end
