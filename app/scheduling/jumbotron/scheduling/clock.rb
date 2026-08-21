# frozen_string_literal: true

module Jumbotron
  module Scheduling
    class Clock
      MINUTE = 17
      HOUR = 6
      WEEKDAY = 3
      WEEKDAY_NAME = "wednesday"

      def self.clock_time
        "#{HOUR}:#{format('%02d', MINUTE)} am"
      end

      def self.fugit(cadence)
        every = cadence.every
        case canonical_unit(cadence.unit)
        when :second then every == 1 ? "every second" : "every #{every} seconds"
        when :minute then every == 1 ? "every minute" : "every #{every} minutes"
        when :hour then hour_fugit(every)
        when :day then day_fugit(every)
        when :week then "every #{WEEKDAY_NAME} at #{clock_time}"
        else
          raise ArgumentError, "unsupported cadence unit: #{cadence.unit}"
        end
      end

      def self.cron(cadence)
        every = cadence.every
        case canonical_unit(cadence.unit)
        when :minute then "*/#{every} * * * *"
        when :hour then hour_cron(every)
        when :day then day_cron(every)
        when :week then "#{MINUTE} #{HOUR} * * #{WEEKDAY}"
        else
          raise ArgumentError, "unsupported cadence unit: #{cadence.unit}"
        end
      end

      def self.canonical_unit(unit)
        unit.to_s.sub(/s\z/, "").to_sym
      end

      def self.hour_fugit(every)
        every == 1 ? "every hour at minute #{MINUTE}" : "every #{every} hours at minute #{MINUTE}"
      end

      def self.day_fugit(every)
        every == 1 ? "every day at #{clock_time}" : "every #{every} days at #{clock_time}"
      end

      def self.hour_cron(every)
        every == 1 ? "#{MINUTE} * * * *" : "#{MINUTE} */#{every} * * *"
      end

      def self.day_cron(every)
        every == 1 ? "#{MINUTE} #{HOUR} * * *" : "#{MINUTE} #{HOUR} */#{every} * *"
      end
    end
  end
end
