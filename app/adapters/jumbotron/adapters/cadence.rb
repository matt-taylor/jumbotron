# frozen_string_literal: true

module Jumbotron
  module Adapters
    class Cadence
      UNITS = {
        second: 1,
        seconds: 1,
        minute: 60,
        minutes: 60,
        hour: 3600,
        hours: 3600,
        day: 86_400,
        days: 86_400,
        week: 604_800,
        weeks: 604_800
      }.freeze

      attr_reader :every, :unit

      def initialize(every:, unit:)
        @every = Integer(every)
        @unit = unit.to_sym
        raise ArgumentError, "every must be positive" unless @every.positive?
        raise ArgumentError, "unknown cadence unit: #{unit}" unless UNITS.key?(@unit)
      end

      def interval_seconds
        every * UNITS.fetch(unit)
      end

      def ==(other)
        other.is_a?(self.class) && every == other.every && unit == other.unit
      end
      alias eql? ==

      def hash
        [self.class, every, unit].hash
      end
    end
  end
end
