# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module SyntheticObservation
          Current = Data.define(:lifecycle, :progress, :home_score, :away_score)
          Observation = Data.define(
            :lifecycle,
            :progress,
            :home_score,
            :away_score,
            :home_result,
            :away_result
          )

          QUARTER_SECONDS = TimelineObservation::QUARTER_SECONDS
          HALFTIME_SECONDS = TimelineObservation::HALFTIME_SECONDS
          TOTAL_SECONDS = TimelineObservation::TOTAL_SECONDS

          module_function

          def call(now:, kickoff:, plan:, current:)
            proposed = TimelineObservation.call(now: now, kickoff: kickoff, plan: plan)
            MonotonicObservation.call(proposed: proposed, current: current, plan: plan)
          end
        end
      end
    end
  end
end
