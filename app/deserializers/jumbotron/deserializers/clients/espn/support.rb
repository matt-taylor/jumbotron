# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module Support
          module_function

          def types
            CommandTower::Deserializers::Clients::Types
          end

          def payload
            CommandTower::Deserializers::Clients::Payload
          end

          def missing
            CommandTower::Deserializers::Clients::Missing
          end

          def ensure_hash!(value, label:)
            return if value.is_a?(Hash)

            raise CommandTower::Clients::Errors::DeserializationError.new(
              message: "#{label} payload must be a Hash",
              details: {
                path: "",
                expected: "Hash",
                actual: value.class.name,
                rule: "type",
                messages: ["#{label} payload must be a Hash"]
              }
            )
          end

          def nest(key, raw)
            return raw if raw.equal?(missing) || raw.nil?

            yield raw
          rescue CommandTower::Clients::Errors::DeserializationError => e
            raise CommandTower::Deserializers::Clients::Errors.prefix(e, key)
          end

          def whole_number(raw)
            return raw if raw.equal?(missing) || raw.nil?
            return raw.to_i if raw.is_a?(Float) && raw == raw.to_i

            raw
          end

          def coerce_id(raw)
            return raw if raw.equal?(missing) || raw.nil? || raw.is_a?(String)

            raw.to_s
          end
        end
      end
    end
  end
end
