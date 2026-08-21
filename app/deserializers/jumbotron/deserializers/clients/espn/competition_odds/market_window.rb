# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class MarketWindow
            class Result < CommandTower::Deserializers::Clients::Result
              field :over, type: Price::Result, nullable: true
              field :under, type: Price::Result, nullable: true
              field :total, type: PointSpread::Result, nullable: true
              field :draw, type: Price::Result, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "market_window")

              Result.build!(
                over: Support.nest("over", Support.payload.fetch(payload, "over")) { |raw| Price.call(raw) },
                under: Support.nest("under", Support.payload.fetch(payload, "under")) { |raw| Price.call(raw) },
                total: Support.nest("total", Support.payload.fetch(payload, "total")) { |raw| PointSpread.call(raw) },
                draw: Support.nest("draw", Support.payload.fetch(payload, "draw")) { |raw| Price.call(raw) }
              )
            end
          end
        end
      end
    end
  end
end
