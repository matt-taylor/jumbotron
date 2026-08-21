# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Venue
          class Result < CommandTower::Deserializers::Clients::Result
            field :id, type: Support.types.string, required: true
            field :full_name, type: Support.types.string, required: true
            field :indoor, type: Support.types.boolean, nullable: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "venue")

            Result.build!(
              id: coerce_id(Support.payload.fetch(payload, "id")),
              full_name: Support.payload.fetch(payload, "fullName"),
              indoor: Support.payload.fetch(payload, "indoor")
            )
          end

          def self.coerce_id(raw)
            return raw if raw.equal?(Support.missing) || raw.nil? || raw.is_a?(String)

            raw.to_s
          end
          private_class_method :coerce_id
        end
      end
    end
  end
end
