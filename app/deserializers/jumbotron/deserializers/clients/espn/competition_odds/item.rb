# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class Item
            class Result < CommandTower::Deserializers::Clients::Result
              field :ref, type: Support.types.string, nullable: true
              field :details, type: Support.types.string, nullable: true
              field :spread, type: Support.types.float, nullable: true
              field :over_under, type: Support.types.float, nullable: true
              field :over_odds, type: Support.types.float, nullable: true
              field :under_odds, type: Support.types.float, nullable: true
              field :listed_provider, type: ListedProvider::Result, required: true
              field :home_team_odds, type: TeamOdds::Result, nullable: true
              field :away_team_odds, type: TeamOdds::Result, nullable: true
              field :draw_odds, type: DrawOdds::Result, nullable: true
              field :open, type: MarketWindow::Result, nullable: true
              field :current, type: MarketWindow::Result, nullable: true
              field :close, type: MarketWindow::Result, nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "competition_odds_item")

              Result.build!(
                ref: Support.payload.fetch(payload, "$ref"),
                details: Support.payload.fetch(payload, "details"),
                spread: Support.payload.fetch(payload, "spread"),
                over_under: Support.payload.fetch(payload, "overUnder"),
                over_odds: Support.payload.fetch(payload, "overOdds"),
                under_odds: Support.payload.fetch(payload, "underOdds"),
                listed_provider: Support.nest("provider", Support.payload.fetch(payload, "provider")) do |raw|
                  ListedProvider.call(raw)
                end,
                home_team_odds: Support.nest("homeTeamOdds", Support.payload.fetch(payload, "homeTeamOdds")) do |raw|
                  TeamOdds.call(raw)
                end,
                away_team_odds: Support.nest("awayTeamOdds", Support.payload.fetch(payload, "awayTeamOdds")) do |raw|
                  TeamOdds.call(raw)
                end,
                draw_odds: Support.nest("drawOdds", Support.payload.fetch(payload, "drawOdds")) do |raw|
                  DrawOdds.call(raw)
                end,
                open: Support.nest("open", Support.payload.fetch(payload, "open")) { |raw| MarketWindow.call(raw) },
                current: Support.nest(
                  "current",
                  Support.payload.fetch(payload, "current")
                ) { |raw| MarketWindow.call(raw) },
                close: Support.nest("close", Support.payload.fetch(payload, "close")) { |raw| MarketWindow.call(raw) }
              )
            end
          end
        end
      end
    end
  end
end
