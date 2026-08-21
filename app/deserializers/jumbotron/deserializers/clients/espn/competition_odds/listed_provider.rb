# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class ListedProvider
            class Result < CommandTower::Deserializers::Clients::Result
              field :id, type: Support.types.string, required: true
              field :name, type: Support.types.string, required: true
              field :priority, type: Support.types.integer, nullable: true
              field :ref, type: Support.types.string, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "listed_provider")

              Result.build!(
                id: Support.coerce_id(Support.payload.fetch(payload, "id")),
                name: Support.payload.fetch(payload, "name"),
                priority: Support.whole_number(Support.payload.fetch(payload, "priority")),
                ref: Support.payload.fetch(payload, "$ref")
              )
            end
          end
        end
      end
    end
  end
end
