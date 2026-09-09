# frozen_string_literal: true

require "bigdecimal"
require "digest"

module Jumbotron
  module Services
    module Sandbox
      class SelectLineBasis < CommandTower::Services::ApplicationService
        SPREADS = (-21..21).reject(&:zero?).map { |value| BigDecimal(value.to_s) / 2 }.freeze
        TOTALS = (75..109).map { |value| BigDecimal(value.to_s) / 2 }.freeze

        validate :source_game_id, required: true
        validate :reset_fingerprint, required: true
        validate :source_spread, required: false
        validate :source_total, required: false

        def call # rubocop:disable Metrics/AbcSize
          source_pair = normalized_source_pair
          pair = source_pair || fallback_pair
          context.home_spread = pair.fetch(:home_spread)
          context.total = pair.fetch(:total)
          context.line_source = source_pair ? "source_consensus" : "synthetic_fallback"
          context.line_fingerprint = Digest::SHA256.hexdigest(
            "#{reset_fingerprint}:#{source_game_id}:#{context.home_spread}:#{context.total}"
          )
        end

        private

        def normalized_source_pair
          return if source_spread.nil? || source_total.nil?

          spread = round_half(source_spread)
          total = round_half(source_total)
          return unless total.positive? && implied_scores(spread, total).all?(&:positive?)

          { home_spread: spread, total: total }
        rescue ArgumentError, TypeError
          nil
        end

        def fallback_pair
          candidates = weighted_fallback_candidates
          index = Digest::SHA256.hexdigest("#{reset_fingerprint}:#{source_game_id}").to_i(16) % candidates.length
          candidates.fetch(index)
        end

        def weighted_fallback_candidates
          SPREADS.product(TOTALS).filter_map do |spread, total|
            next unless implied_scores(spread, total).all? { |score| score.between?(10, 38) }

            pair = { home_spread: spread, total: total }
            weight = (spread.abs <= 6.5 ? 2 : 1) * (total.between?(41.5, 48.5) ? 2 : 1)
            Array.new(weight, pair)
          end.flatten
        end

        def implied_scores(spread, total)
          [(total - spread) / 2, (total + spread) / 2]
        end

        def round_half(value)
          BigDecimal((BigDecimal(value.to_s) * 2).round.to_s) / 2
        end
      end
    end
  end
end
