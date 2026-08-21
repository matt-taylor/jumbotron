# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class SideQuote
            class Result < CommandTower::Deserializers::Clients::Result
              field :favorite, type: Support.types.boolean, nullable: true
              field :point_spread, type: PointSpread::Result, nullable: true
              field :spread, type: Price::Result, nullable: true
              field :money_line, type: Price::Result, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "side_quote")

              Result.build!(
                favorite: Support.payload.fetch(payload, "favorite"),
                point_spread: Support.nest("pointSpread", Support.payload.fetch(payload, "pointSpread")) do |raw|
                  PointSpread.call(raw)
                end,
                spread: Support.nest("spread", Support.payload.fetch(payload, "spread")) { |raw| Price.call(raw) },
                money_line: Support.nest("moneyLine", Support.payload.fetch(payload, "moneyLine")) do |raw|
                  Price.call(raw)
                end
              )
            end
          end
        end
      end
    end
  end
end
