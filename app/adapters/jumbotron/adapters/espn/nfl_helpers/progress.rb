# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        module Progress
          NIL_LIFECYCLES = %w[scheduled postponed cancelled].freeze
          INTERMISSION_PATTERN = /halftime/i

          module_function

          def call(status, lifecycle:)
            return if NIL_LIFECYCLES.include?(lifecycle.to_s)
            return quarter_intermission if intermission?(status)

            period = status.period
            return if period.nil? || period < 1

            kind = period <= 4 ? "quarter" : "overtime"
            number = period <= 4 ? period : period - 4
            build(state: "active", kind: kind, number: number, clock: clock_for(status))
          end

          def intermission?(status)
            [status.type_name, status.type_description, status.type_detail, status.type_short_detail]
              .compact
              .any? { |value| INTERMISSION_PATTERN.match?(value) }
          end

          def quarter_intermission
            build(state: "intermission", kind: "quarter", number: 2, clock: nil)
          end

          def clock_for(status)
            seconds = status.clock.is_a?(Integer) ? status.clock : nil
            display = status.display_clock.presence
            return if seconds.nil? && display.nil?

            Canonical::GameClock.new(mode: "remaining", seconds: seconds, display: display)
          end

          def build(state:, kind:, number:, clock:)
            Canonical::GameProgress.new(
              state: state,
              segment: Canonical::GameSegment.new(kind: kind, number: number),
              clock: clock
            )
          end
        end
      end
    end
  end
end
