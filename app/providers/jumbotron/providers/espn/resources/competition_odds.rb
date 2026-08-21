# frozen_string_literal: true

module Jumbotron
  module Providers
    module Espn
      module Resources
        class CompetitionOdds
          def self.acquire(sport:, league:, event_id:, competition_id:)
            cooldown = Cooldown.new
            return CommandTower::Clients::ClientResult.failure(error: CooldownActiveError.new) if cooldown.cooling_down?

            result = Jumbotron::Clients.espn.competition_odds.get(
              sport: sport,
              league: league,
              event_id: event_id,
              competition_id: competition_id
            )
            if result.success?
              cooldown.record_success!
            else
              cooldown.record_failure!(result.error)
            end
            result
          end
        end
      end
    end
  end
end
