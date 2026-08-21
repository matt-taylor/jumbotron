# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class ResolveCurrentLines < CommandTower::Services::ApplicationService
        validate :game, required: true

        def call
          resolved = ResolveCurrentLinesForGames.call(game_ids: [game.id])
          unless resolved.success?
            context.fail!(application_error: resolved.errors.first)
            return
          end

          context.current_lines = Array(resolved.data[:current_lines])
        end
      end
    end
  end
end
