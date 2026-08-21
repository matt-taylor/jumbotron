# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class PointSpread
            class Result < CommandTower::Deserializers::Clients::Result
              field :american, type: Support.types.string, nullable: true
              field :alternate_display_value, type: Support.types.string, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "point_spread")

              Result.build!(
                american: Support.payload.fetch(payload, "american"),
                alternate_display_value: Support.payload.fetch(payload, "alternateDisplayValue")
              )
            end
          end
        end
      end
    end
  end
end
