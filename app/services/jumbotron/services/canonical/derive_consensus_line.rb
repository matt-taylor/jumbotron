# frozen_string_literal: true

require "bigdecimal"

module Jumbotron
  module Services
    module Canonical
      class DeriveConsensusLine < CommandTower::Services::ApplicationService
        CONSENSUS_MARKETS = %w[spread total].freeze
        LIVE_ODDS_NAME = /\blive odds\b/i

        validate :game, required: true
        validate :current_lines, required: false

        def call
          currents = current_lines
          if currents.nil?
            resolved = ResolveCurrentLines.call(game: game)
            unless resolved.success?
              context.fail!(application_error: resolved.errors.first)
              return
            end
            currents = Array(resolved.data[:current_lines])
          end

          context.consensus_lines = self.class.from_current_lines(
            game_id: game.id,
            current_lines: currents
          )
        end

        def self.from_current_lines(game_id:, current_lines:)
          currents = Array(current_lines)
          latest_at = currents.filter_map(&:observed_at).max
          eligible = currents.select { |line| eligible?(line, latest_at) }
          eligible.group_by { |line| [line.market, line.outcome] }.map do |(_key, members)|
            to_consensus(game_id, members)
          end
        end

        def self.eligible?(line, latest_at)
          return false unless CONSENSUS_MARKETS.include?(line.market)
          return false if line.line_value.nil?
          return false if line.bookmaker_name.to_s.match?(LIVE_ODDS_NAME)
          return false if latest_at.nil?

          line.observed_at == latest_at
        end

        def self.to_consensus(game_id, members)
          values = members.map { |line| BigDecimal(line.line_value.to_s) }
          mean = values.sum / values.size
          Jumbotron::Canonical::ConsensusLine.new(
            game_id: game_id,
            market: members.first.market,
            outcome: members.first.outcome,
            line_value: mean,
            constituent_count: members.size,
            constituents: members.map do |line|
              Jumbotron::Canonical::ConsensusConstituent.new(
                line_observation_id: line.line_observation_id,
                bookmaker_id: line.bookmaker_id
              )
            end
          )
        end
      end
    end
  end
end
