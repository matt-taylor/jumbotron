# frozen_string_literal: true

require "time"

module Jumbotron
  module Deserializers
    module Public
      class ResetSandboxProjection < CommandTower::Deserializers::ApplicationDeserializer
        def call(params)
          sandbox = unwrap(require_string(unwrap(fetch_param(params, :sandbox)), field: "sandbox"))
          return sandbox if deserializer_result?(sandbox)

          start_week = positive_integer(params, :start_week)
          return start_week if deserializer_result?(start_week)

          anchor_day = positive_integer(params, :anchor_day)
          return anchor_day if deserializer_result?(anchor_day)

          now = parse_time(unwrap(fetch_param(params, :now)))
          return now if deserializer_result?(now)

          success(
            Jumbotron::Public::ResetSandboxProjectionRequest.new(
              sandbox: sandbox,
              start_week: start_week,
              anchor_day: anchor_day,
              now: now
            )
          )
        end

        private

        def positive_integer(params, field)
          raw = unwrap(fetch_param(params, field))
          return raw if deserializer_result?(raw)

          unwrap(require_integer(raw, field: field.to_s, min: 1))
        end

        def parse_time(raw)
          return raw if raw.is_a?(Time) || raw.is_a?(ActiveSupport::TimeWithZone)

          Time.iso8601(raw.to_s)
        rescue ArgumentError, TypeError
          failure(errors: [{ code: "invalid_request", message: "now must be an ISO8601 time" }])
        end
      end
    end
  end
end
