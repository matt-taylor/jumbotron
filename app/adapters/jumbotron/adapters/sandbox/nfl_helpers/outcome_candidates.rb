# frozen_string_literal: true

require "bigdecimal"

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module OutcomeCandidates
          Outcome = Data.define(:home_score, :away_score)
          SCORE_OFFSETS = [[0, 0], [3, 0], [0, 3], [-3, 0], [0, -3]].freeze

          module_function

          def call(home_spread:, total:)
            spread_value = BigDecimal(home_spread.to_s)
            total_value = BigDecimal(total.to_s)
            home = ((total_value - spread_value) / 2).round
            away = ((total_value + spread_value) / 2).round

            SCORE_OFFSETS.filter_map do |home_offset, away_offset|
              candidate(home + home_offset, away + away_offset)
            end.uniq
          rescue ArgumentError, TypeError
            []
          end

          def candidate(home_score, away_score)
            return if home_score.negative? || away_score.negative? || home_score == away_score

            Outcome.new(home_score: home_score, away_score: away_score)
          end
          private_class_method :candidate
        end
      end
    end
  end
end
