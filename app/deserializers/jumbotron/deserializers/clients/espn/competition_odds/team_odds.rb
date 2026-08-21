# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class TeamOdds
            class Result < CommandTower::Deserializers::Clients::Result
              field :favorite, type: Support.types.boolean, nullable: true
              field :underdog, type: Support.types.boolean, nullable: true
              field :money_line, type: Support.types.float, nullable: true
              field :spread_odds, type: Support.types.float, nullable: true
              field :open, type: SideQuote::Result, nullable: true
              field :current, type: SideQuote::Result, nullable: true
              field :close, type: SideQuote::Result, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "team_odds")

              Result.build!(
                favorite: Support.payload.fetch(payload, "favorite"),
                underdog: Support.payload.fetch(payload, "underdog"),
                money_line: Support.payload.fetch(payload, "moneyLine"),
                spread_odds: Support.payload.fetch(payload, "spreadOdds"),
                open: Support.nest("open", Support.payload.fetch(payload, "open")) { |raw| SideQuote.call(raw) },
                current: Support.nest(
                  "current",
                  Support.payload.fetch(payload, "current")
                ) { |raw| SideQuote.call(raw) },
                close: Support.nest("close", Support.payload.fetch(payload, "close")) { |raw| SideQuote.call(raw) }
              )
            end
          end
        end
      end
    end
  end
end
