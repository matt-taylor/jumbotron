# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Season
          class Result < CommandTower::Deserializers::Clients::Result
            field :year, type: Support.types.integer, required: true
            field :type, type: Support.types.integer, required: true
            field :slug, type: Support.types.string, nullable: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "season")

            Result.build!(
              year: Support.payload.fetch(payload, "year"),
              type: Support.payload.fetch(payload, "type"),
              slug: Support.payload.fetch(payload, "slug")
            )
          end
        end
      end
    end
  end
end
