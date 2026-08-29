# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class VenueAddress
          class Result < CommandTower::Deserializers::Clients::Result
            field :city, type: Support.types.string, nullable: true
            field :state, type: Support.types.string, nullable: true
            field :country, type: Support.types.string, nullable: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "venue.address")

            Result.build!(
              city: Support.payload.fetch(payload, "city"),
              state: Support.payload.fetch(payload, "state"),
              country: Support.payload.fetch(payload, "country")
            )
          end
        end
      end
    end
  end
end
