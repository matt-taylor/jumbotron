# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Status
          class Result < CommandTower::Deserializers::Clients::Result
            field :clock, type: Support.types.union(Support.types.integer, Support.types.string), nullable: true
            field :display_clock, type: Support.types.string, nullable: true
            field :period, type: Support.types.integer, nullable: true
            field :type_id, type: Support.types.string, nullable: true
            field :type_name, type: Support.types.string, required: true
            field :type_state, type: Support.types.string, required: true
            field :type_completed, type: Support.types.boolean, required: true
            field :type_description, type: Support.types.string, nullable: true
            field :type_detail, type: Support.types.string, nullable: true
            field :type_short_detail, type: Support.types.string, nullable: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "status")
            type = fetch_type!(payload)

            Result.build!(
              clock: Support.whole_number(Support.payload.fetch(payload, "clock")),
              display_clock: Support.payload.fetch(payload, "displayClock"),
              period: Support.payload.fetch(payload, "period"),
              type_id: coerce_string(Support.payload.fetch(type, "id")),
              type_name: Support.payload.fetch(type, "name"),
              type_state: Support.payload.fetch(type, "state"),
              type_completed: Support.payload.fetch(type, "completed"),
              type_description: Support.payload.fetch(type, "description"),
              type_detail: Support.payload.fetch(type, "detail"),
              type_short_detail: Support.payload.fetch(type, "shortDetail")
            )
          end

          def self.fetch_type!(payload)
            raw = Support.payload.fetch(payload, "type")
            if raw.equal?(Support.missing) || raw.nil?
              raise CommandTower::Clients::Errors::DeserializationError.new(
                message: "status.type is required",
                details: {
                  path: "type",
                  expected: "Hash",
                  actual: "missing",
                  rule: "required",
                  messages: ["status.type is required"]
                }
              )
            end

            Support.ensure_hash!(raw, label: "status.type")
            raw
          end
          private_class_method :fetch_type!

          def self.coerce_string(raw)
            return raw if raw.equal?(Support.missing) || raw.nil? || raw.is_a?(String)

            raw.to_s
          end
          private_class_method :coerce_string
        end
      end
    end
  end
end
