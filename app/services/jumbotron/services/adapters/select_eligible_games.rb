# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class SelectEligibleGames < CommandTower::Services::ApplicationService
        validate :adapter, required: true
        validate :policy, required: true
        validate :now, required: true

        def call
          league = find_league
          if league.nil?
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::LeagueNotFoundError.new(
                details: { league_id: "#{adapter.sport}/#{adapter.league}" }
              )
            )
            return
          end

          games = Game.where(league_id: league.id)
                      .includes(:season, :season_phase, :schedule_group)
                      .select { |game| policy.eligible?(game, now: now) }

          context.league = league
          context.games = games
        end

        private

        def find_league
          sport = Sport.where("LOWER(name) = ?", adapter.sport.downcase).first
          return if sport.nil?

          sport.leagues.where("LOWER(name) = ?", adapter.league.downcase).first
        end
      end
    end
  end
end
