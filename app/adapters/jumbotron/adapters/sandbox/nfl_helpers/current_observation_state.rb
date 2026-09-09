# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module CurrentObservationState
          module_function

          def call(game)
            SyntheticObservation::Current.new(
              lifecycle: game.lifecycle,
              progress: progress(game),
              home_score: participant(game, "home").score,
              away_score: participant(game, "away").score
            )
          end

          def participant(game, role)
            game.game_participants.find { |row| row.role == role } ||
              raise(ArgumentError, "sandbox game requires #{role} participant")
          end
          private_class_method :participant

          def progress(game)
            return if game.progress_state.nil?

            Jumbotron::Canonical::GameProgress.new(
              state: game.progress_state,
              segment: Jumbotron::Canonical::GameSegment.new(
                kind: game.progress_segment_kind,
                number: game.progress_segment_number
              ),
              clock: clock(game)
            )
          end
          private_class_method :progress

          def clock(game)
            return if game.progress_clock_mode.nil?

            Jumbotron::Canonical::GameClock.new(
              mode: game.progress_clock_mode,
              seconds: game.progress_clock_seconds,
              display: game.progress_clock_display
            )
          end
          private_class_method :clock
        end
      end
    end
  end
end
