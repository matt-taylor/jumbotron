# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class LoadIncludedLines < CommandTower::Services::ApplicationService
        validate :games, required: false
        validate :includes, required: false

        def call
          context.current_lines = []
          context.consensus_lines = []
          return if Array(games).empty?
          return unless needs_currents? || needs_consensus?

          resolved = ResolveCurrentLinesForGames.call(games: games)
          unless resolved.success?
            context.fail!(application_error: resolved.errors.first)
            return
          end
          context.current_lines = Array(resolved.data[:current_lines])

          return unless needs_consensus?

          derived = DeriveConsensusForGames.call(current_lines: context.current_lines)
          unless derived.success?
            context.fail!(application_error: derived.errors.first)
            return
          end

          context.consensus_lines = Array(derived.data[:consensus_lines])
        end

        private

        def needs_currents?
          Array(includes).include?(:current_lines)
        end

        def needs_consensus?
          includes = Array(self.includes)
          includes.include?(:consensus) || includes.include?(:consensus_constituents)
        end
      end
    end
  end
end
