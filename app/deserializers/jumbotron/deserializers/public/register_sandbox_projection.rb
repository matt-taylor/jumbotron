# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      class RegisterSandboxProjection < CommandTower::Deserializers::ApplicationDeserializer
        FIELDS = %i[sport league season season_phase].freeze

        def call(params)
          name = unwrap(require_string(unwrap(fetch_param(params, :name)), field: "name"))
          return name if deserializer_result?(name)

          source = unwrap(fetch_param(params, :source))
          return source if deserializer_result?(source)
          return invalid("source must be a hash") unless source.is_a?(Hash)

          selector = parse_selector(source)
          return selector if deserializer_result?(selector)

          success(Jumbotron::Public::RegisterSandboxProjectionRequest.new(name: name, source: selector))
        end

        private

        def parse_selector(source)
          values = FIELDS.to_h do |field|
            value = source[field] || source[field.to_s]
            parsed = unwrap(require_string(value, field: "source.#{field}"))
            return parsed if deserializer_result?(parsed)

            [field, parsed]
          end
          Jumbotron::Public::SandboxScheduleSelector.new(**values)
        end

        def invalid(message)
          failure(errors: [{ code: "invalid_request", message: message }])
        end
      end
    end
  end
end
