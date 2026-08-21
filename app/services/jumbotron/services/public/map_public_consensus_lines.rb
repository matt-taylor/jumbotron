# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class MapPublicConsensusLines < CommandTower::Services::ApplicationService
        validate :consensus_lines, required: false
        validate :current_lines, required: false
        validate :include_constituents, required: false

        def call
          context.public_consensus_lines = Array(consensus_lines).map do |line|
            Jumbotron::Public::ConsensusLine.new(
              game_id: line.game_id,
              market: line.market,
              outcome: line.outcome,
              line_value: line.line_value,
              constituent_count: line.constituent_count,
              observed_at: observed_at_for(line),
              constituents: constituents_for(line)
            )
          end
        end

        private

        def observed_at_for(line)
          matching = Array(current_lines).select do |current|
            current.game_id == line.game_id && current.market == line.market && current.outcome == line.outcome
          end
          matching.map(&:observed_at).compact.max
        end

        def constituents_for(line)
          return [] unless include_constituents

          Array(line.constituents).map do |constituent|
            Jumbotron::Public::ConsensusConstituent.new(bookmaker_id: constituent.bookmaker_id)
          end
        end
      end
    end
  end
end
