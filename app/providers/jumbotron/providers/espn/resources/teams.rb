# frozen_string_literal: true

module Jumbotron
  module Providers
    module Espn
      module Resources
        class Teams
          def self.acquire(adapter:, **query)
            Jumbotron::Clients.espn.teams.get(
              sport: adapter.sport,
              league: adapter.league,
              **query
            )
          end
        end
      end
    end
  end
end
