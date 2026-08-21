# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Team
          class Result < CommandTower::Deserializers::Clients::Result
            field :id, type: Support.types.string, required: true
            field :uid, type: Support.types.string, nullable: true
            field :abbreviation, type: Support.types.string, nullable: true
            field :display_name, type: Support.types.string, required: true
            field :short_display_name, type: Support.types.string, nullable: true
            field :name, type: Support.types.string, nullable: true
            field :location, type: Support.types.string, nullable: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "team")

            Result.build!(
              id: coerce_id(Support.payload.fetch(payload, "id")),
              uid: Support.payload.fetch(payload, "uid"),
              abbreviation: Support.payload.fetch(payload, "abbreviation"),
              display_name: Support.payload.fetch(payload, "displayName"),
              short_display_name: Support.payload.fetch(payload, "shortDisplayName"),
              name: Support.payload.fetch(payload, "name"),
              location: Support.payload.fetch(payload, "location")
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
