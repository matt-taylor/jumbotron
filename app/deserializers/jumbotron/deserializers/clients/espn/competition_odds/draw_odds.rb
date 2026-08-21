# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class DrawOdds
            class Result < CommandTower::Deserializers::Clients::Result
              field :money_line, type: Support.types.float, nullable: true
              field :summary, type: Support.types.string, nullable: true
              field :value, type: Support.types.float, nullable: true
              field :handicap, type: Support.types.float, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "draw_odds")

              Result.build!(
                money_line: Support.payload.fetch(payload, "moneyLine"),
                summary: Support.payload.fetch(payload, "summary"),
                value: Support.payload.fetch(payload, "value"),
                handicap: Support.payload.fetch(payload, "handicap")
              )
            end
          end
        end
      end
    end
  end
end
