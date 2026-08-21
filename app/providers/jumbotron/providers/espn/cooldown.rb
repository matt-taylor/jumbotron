# frozen_string_literal: true

module Jumbotron
  module Providers
    module Espn
      # Provider-wide ESPN availability cooldown. Backed by Rails-configured cache/store.
      class Cooldown
        STATE_KEY = "jumbotron:providers:espn:cooldown"
        BASE_DELAY_SECONDS = 5
        MAX_DELAY_SECONDS = 180

        def initialize(store: Rails.cache, clock: -> { Time.current })
          @store = store
          @clock = clock
        end

        # rubocop:disable Naming/PredicateMethod -- bang mutators report whether state changed
        def record_failure!(error, now: clock.call)
          return false unless ProviderFailure.availability_failure?(error)

          state = read_state
          count = state.fetch(:failure_count, 0) + 1
          delay = delay_for(count)
          write_state(failure_count: count, cooldown_until: now + delay)
          true
        end

        def record_success!
          store.delete(STATE_KEY)
          true
        end
        # rubocop:enable Naming/PredicateMethod

        def cooling_down?(now: clock.call)
          retry_after(now: now).positive?
        end

        def retry_after(now: clock.call)
          until_time = read_state[:cooldown_until]
          return 0 if until_time.nil?

          remaining = (until_time - now).to_f
          remaining.positive? ? remaining.ceil : 0
        end

        def failure_count
          read_state.fetch(:failure_count, 0)
        end

        def self.delay_for(failure_count)
          [BASE_DELAY_SECONDS * (2**(failure_count - 1)), MAX_DELAY_SECONDS].min
        end

        delegate :delay_for, to: :class

        private

        attr_reader :store, :clock

        def read_state
          raw = store.read(STATE_KEY)
          return { failure_count: 0, cooldown_until: nil } if raw.blank?

          {
            failure_count: Integer(raw[:failure_count] || raw["failure_count"] || 0),
            cooldown_until: parse_time(raw[:cooldown_until] || raw["cooldown_until"])
          }
        end

        def write_state(failure_count:, cooldown_until:)
          store.write(
            STATE_KEY,
            { failure_count: failure_count, cooldown_until: cooldown_until.utc.iso8601(6) },
            expires_in: MAX_DELAY_SECONDS * 2
          )
        end

        def parse_time(value)
          return if value.nil?
          return value if value.is_a?(Time)
          return value.to_time if value.respond_to?(:to_time)

          Time.iso8601(value.to_s)
        end
      end
    end
  end
end
