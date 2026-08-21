# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class ResolveCurrentLinesForGames < CommandTower::Services::ApplicationService
        validate :games, required: false

        def call
          resolved = Canonical::ResolveCurrentLinesForGames.call(game_ids: Array(games).map(&:id))
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
