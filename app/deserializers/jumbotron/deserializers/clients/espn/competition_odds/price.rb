# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class Price
            class Result < CommandTower::Deserializers::Clients::Result
              field :value, type: Support.types.float, nullable: true
              field :display_value, type: Support.types.string, nullable: true
              field :alternate_display_value, type: Support.types.string, nullable: true
              field :decimal, type: Support.types.float, nullable: true
              field :fraction, type: Support.types.string, nullable: true
              field :american, type: Support.types.string, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "price")

              Result.build!(
                value: Support.payload.fetch(payload, "value"),
                display_value: Support.payload.fetch(payload, "displayValue"),
                alternate_display_value: Support.payload.fetch(payload, "alternateDisplayValue"),
                decimal: Support.payload.fetch(payload, "decimal"),
                fraction: Support.payload.fetch(payload, "fraction"),
                american: Support.payload.fetch(payload, "american")
              )
            end
          end
        end
      end
    end
  end
end
