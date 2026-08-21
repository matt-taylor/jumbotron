# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class DeriveConsensusForGames < CommandTower::Services::ApplicationService
        validate :current_lines, required: false

        def call
          grouped = Array(current_lines).group_by(&:game_id)
          context.consensus_lines = grouped.flat_map do |game_id, lines|
            DeriveConsensusLine.from_current_lines(game_id: game_id, current_lines: lines)
          end
        end
      end
    end
  end
end
