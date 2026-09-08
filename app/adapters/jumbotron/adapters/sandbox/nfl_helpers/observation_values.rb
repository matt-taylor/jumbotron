# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module ObservationValues
          module_function

          def observation(**attributes)
            defaults = {
              progress: nil,
              home_score: nil,
              away_score: nil,
              home_result: nil,
              away_result: nil
            }
            SyntheticObservation::Observation.new(**defaults, **attributes)
          end

          def progress(state:, quarter:, clock: nil)
            Canonical::GameProgress.new(
              state: state,
              segment: Canonical::GameSegment.new(kind: "quarter", number: quarter),
              clock: clock
            )
          end

          def clock(local_seconds:, quarter_seconds:, game_clock_seconds:)
            elapsed = ((local_seconds / quarter_seconds.to_f) * game_clock_seconds).floor
            remaining = [game_clock_seconds - elapsed, 0].max
            Canonical::GameClock.new(
              mode: "remaining",
              seconds: remaining,
              display: format("%<minutes>d:%<seconds>02d", minutes: remaining / 60, seconds: remaining % 60)
            )
          end

          def score_at(final_score, fraction)
            (final_score * fraction).floor
          end

          def results(home_score, away_score)
            return %w[win loss] if home_score > away_score
            return %w[loss win] if away_score > home_score

            %w[tie tie]
          end
        end
      end
    end
  end
end
