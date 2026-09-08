# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module MonotonicObservation
          ACTIVE_ORDINALS = { 1 => 1, 2 => 2, 3 => 4, 4 => 5 }.freeze

          module_function

          def call(proposed:, current:, plan:)
            validate_current_scores!(current, plan)
            proposed_ordinal = ordinal(proposed.lifecycle, proposed.progress)
            current_ordinal = ordinal(current.lifecycle, current.progress)
            state = select_state(proposed, current, proposed_ordinal, current_ordinal)
            build_observation(state, proposed, current, plan)
          end

          def select_state(proposed, current, proposed_ordinal, current_ordinal)
            return current if current_ordinal > proposed_ordinal
            return proposed unless current_ordinal == proposed_ordinal
            return proposed unless active_progress?(proposed.progress) && active_progress?(current.progress)

            proposed.with(progress: clamp_clock(proposed.progress, current.progress))
          end
          private_class_method :select_state

          def build_observation(state, proposed, current, plan)
            return completed_observation(plan) if state.lifecycle == "completed"
            return state if state.lifecycle == "scheduled"

            ObservationValues.observation(
              lifecycle: state.lifecycle,
              progress: state.progress,
              home_score: [proposed.home_score || 0, current.home_score || 0].max,
              away_score: [proposed.away_score || 0, current.away_score || 0].max
            )
          end
          private_class_method :build_observation

          def completed_observation(plan)
            home_result, away_result = ObservationValues.results(plan.home_score, plan.away_score)
            ObservationValues.observation(
              lifecycle: "completed",
              progress: nil,
              home_score: plan.home_score,
              away_score: plan.away_score,
              home_result: home_result,
              away_result: away_result
            )
          end
          private_class_method :completed_observation

          def active_progress?(progress)
            progress&.state == "active"
          end
          private_class_method :active_progress?

          def clamp_clock(proposed, current)
            proposed_seconds = proposed.clock&.seconds
            current_seconds = current.clock&.seconds
            return proposed if proposed_seconds.nil? || current_seconds.nil? || proposed_seconds <= current_seconds

            proposed.with(clock: current.clock)
          end
          private_class_method :clamp_clock

          def ordinal(lifecycle, progress)
            return 0 if lifecycle == "scheduled"
            return 6 if lifecycle == "completed"

            validate_in_progress!(lifecycle, progress)
            return 3 if progress.state == "intermission" && progress.segment.number == 2

            active_ordinal(progress)
          end
          private_class_method :ordinal

          def validate_in_progress!(lifecycle, progress)
            raise ArgumentError, "unsupported sandbox lifecycle #{lifecycle.inspect}" unless lifecycle == "in_progress"
            return if %w[active intermission].include?(progress&.state)

            raise ArgumentError, "in-progress sandbox game requires canonical progress"
          end
          private_class_method :validate_in_progress!

          def active_ordinal(progress)
            return ACTIVE_ORDINALS.fetch(progress.segment.number) if progress.state == "active"

            raise ArgumentError, "sandbox intermission must follow quarter two"
          rescue KeyError
            raise ArgumentError, "sandbox game requires quarter progress from 1 through 4"
          end
          private_class_method :active_ordinal

          def validate_current_scores!(current, plan)
            return if valid_score?(current.home_score, plan.home_score) &&
                      valid_score?(current.away_score, plan.away_score)

            raise ArgumentError, "persisted sandbox score exceeds selected final"
          end
          private_class_method :validate_current_scores!

          def valid_score?(score, final_score)
            score.nil? || score <= final_score
          end
          private_class_method :valid_score?
        end
      end
    end
  end
end
