# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class EnsureLeague < CommandTower::Services::ApplicationService
        validate :adapter, required: true

        def call
          sport = find_or_create_sport
          league = find_or_create_league(sport)
          context.league = league
        end

        private

        def find_or_create_sport
          existing = Jumbotron::Sport.where("LOWER(name) = ?", adapter.sport.downcase).first
          existing || Jumbotron::Sport.create!(name: adapter.sport)
        end

        def find_or_create_league(sport)
          existing = sport.leagues.where("LOWER(name) = ?", adapter.league.downcase).first
          existing || sport.leagues.create!(name: adapter.league)
        end
      end
    end
  end
end
