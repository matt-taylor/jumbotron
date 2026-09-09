# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module TimelineObservation
          QUARTER_SECONDS = 27.5.minutes.to_i
          HALFTIME_SECONDS = 10.minutes.to_i
          ACTIVE_SECONDS = QUARTER_SECONDS * 4
          TOTAL_SECONDS = ACTIVE_SECONDS + HALFTIME_SECONDS
          GAME_CLOCK_SECONDS = 15.minutes.to_i
          STAGES = [
            [QUARTER_SECONDS, :q1],
            [QUARTER_SECONDS * 2, :q2],
            [(QUARTER_SECONDS * 2) + HALFTIME_SECONDS, :halftime],
            [(QUARTER_SECONDS * 3) + HALFTIME_SECONDS, :q3],
            [TOTAL_SECONDS, :q4]
          ].freeze

          module_function

          def call(now:, kickoff:, plan:)
            elapsed = elapsed_seconds(now, kickoff)
            return scheduled_observation if elapsed.negative?
            return completed_observation(plan) if elapsed >= TOTAL_SECONDS

            stage_observation(stage_for(elapsed), elapsed, plan)
          end

          def elapsed_seconds(now, kickoff)
            now.to_time.to_f - kickoff.to_time.to_f
          rescue ArgumentError, NoMethodError, TypeError
            raise ArgumentError, "sandbox observation requires valid now and kickoff times"
          end
          private_class_method :elapsed_seconds

          def stage_for(elapsed)
            STAGES.find { |ending, _stage| elapsed < ending }.last
          end
          private_class_method :stage_for

          def stage_observation(stage, elapsed, plan)
            return halftime_observation(plan) if stage == :halftime

            quarter = { q1: 1, q2: 2, q3: 3, q4: 4 }.fetch(stage)
            local = local_elapsed(stage, elapsed)
            active_observation(quarter, local, active_elapsed(stage, local), plan)
          end
          private_class_method :stage_observation

          def local_elapsed(stage, elapsed)
            offsets = {
              q1: 0,
              q2: QUARTER_SECONDS,
              q3: (QUARTER_SECONDS * 2) + HALFTIME_SECONDS,
              q4: (QUARTER_SECONDS * 3) + HALFTIME_SECONDS
            }
            elapsed - offsets.fetch(stage)
          end
          private_class_method :local_elapsed

          def active_elapsed(stage, local)
            completed_quarters = { q1: 0, q2: 1, q3: 2, q4: 3 }.fetch(stage)
            (completed_quarters * QUARTER_SECONDS) + local
          end
          private_class_method :active_elapsed

          def scheduled_observation
            ObservationValues.observation(lifecycle: "scheduled")
          end
          private_class_method :scheduled_observation

          def active_observation(quarter, local, active_elapsed, plan)
            fraction = active_elapsed / ACTIVE_SECONDS.to_f
            ObservationValues.observation(
              lifecycle: "in_progress",
              progress: ObservationValues.progress(state: "active", quarter: quarter, clock: clock(local)),
              home_score: ObservationValues.score_at(plan.home_score, fraction),
              away_score: ObservationValues.score_at(plan.away_score, fraction)
            )
          end
          private_class_method :active_observation

          def halftime_observation(plan)
            ObservationValues.observation(
              lifecycle: "in_progress",
              progress: ObservationValues.progress(state: "intermission", quarter: 2),
              home_score: ObservationValues.score_at(plan.home_score, 0.5),
              away_score: ObservationValues.score_at(plan.away_score, 0.5)
            )
          end
          private_class_method :halftime_observation

          def completed_observation(plan)
            home_result, away_result = ObservationValues.results(plan.home_score, plan.away_score)
            ObservationValues.observation(
              lifecycle: "completed",
              home_score: plan.home_score,
              away_score: plan.away_score,
              home_result: home_result,
              away_result: away_result
            )
          end
          private_class_method :completed_observation

          def clock(local_seconds)
            ObservationValues.clock(
              local_seconds: local_seconds,
              quarter_seconds: QUARTER_SECONDS,
              game_clock_seconds: GAME_CLOCK_SECONDS
            )
          end
          private_class_method :clock
        end
      end
    end
  end
end
