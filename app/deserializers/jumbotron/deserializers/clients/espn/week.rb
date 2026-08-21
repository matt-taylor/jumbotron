# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Week
          class Result < CommandTower::Deserializers::Clients::Result
            field :number, type: Support.types.integer, required: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "week")

            Result.build!(
              number: Support.payload.fetch(payload, "number")
            )
          end
        end
      end
    end
  end
end
