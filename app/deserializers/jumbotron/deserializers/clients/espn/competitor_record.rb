# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class CompetitorRecord
          class Result < CommandTower::Deserializers::Clients::Result
            field :type, type: Support.types.string, required: true
            field :summary, type: Support.types.string, required: true
            field :name, type: Support.types.string, nullable: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "competitor.record")

            Result.build!(
              type: Support.payload.fetch(payload, "type"),
              summary: Support.payload.fetch(payload, "summary"),
              name: Support.payload.fetch(payload, "name")
            )
          end
        end
      end
    end
  end
end
