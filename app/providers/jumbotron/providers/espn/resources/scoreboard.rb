# frozen_string_literal: true

module Jumbotron
  module Providers
    module Espn
      module Resources
        class Scoreboard
          DISCOVERY_SEASON_TYPES = [1, 2, 3].freeze

          def self.acquire(adapter:, **query)
            cooldown = Cooldown.new
            return CommandTower::Clients::ClientResult.failure(error: CooldownActiveError.new) if cooldown.cooling_down?

            result = Jumbotron::Clients.espn.scoreboard.get(
              sport: adapter.sport,
              league: adapter.league,
              **query
            )
            if result.success?
              cooldown.record_success!
            else
              cooldown.record_failure!(result.error)
            end
            result
          end

          # ESPN year-only and phase-only scoreboards are capped (~100 events) and do not
          # isolate a season. Full-season discovery expands leagues[].calendar into
          # dates + seasontype + week requests, then concatenates unique events.
          def self.acquire_full_season(adapter:, season_year:)
            year = Integer(season_year)
            seed = acquire(adapter: adapter, dates: year)
            return seed unless seed.success?

            requests = discovery_requests(year, seed.output.season_calendar)
            return unavailable_calendar(year) if requests.empty?

            events_by_id = {}
            requests.each do |query|
              result = acquire(adapter: adapter, **query)
              return result unless result.success?

              Array(result.output.events).each do |event|
                events_by_id[event.id] ||= event
              end
            end

            CommandTower::Clients::ClientResult.success(
              output: Jumbotron::Deserializers::Clients::Espn::Scoreboard::Get::Result.build!(
                events: events_by_id.values,
                season_calendar: seed.output.season_calendar
              )
            )
          end

          def self.expand_full_season(adapter:, season_year:)
            year = Integer(season_year)
            seed = acquire(adapter: adapter, dates: year)
            return seed unless seed.success?

            requests = discovery_requests(year, seed.output.season_calendar)
            return unavailable_calendar(year) if requests.empty?

            CommandTower::Clients::ClientResult.success(output: requests)
          end

          def self.discovery_requests(year, season_calendar)
            Array(season_calendar).filter_map do |phase|
              next unless DISCOVERY_SEASON_TYPES.include?(phase.season_type)

              phase.weeks.map do |week|
                { dates: year, season_type: phase.season_type, week: week }
              end
            end.flatten
          end
          private_class_method :discovery_requests

          def self.unavailable_calendar(year)
            CommandTower::Clients::ClientResult.failure(
              error: CommandTower::Clients::Errors::UpstreamError.new(
                message: "ESPN scoreboard calendar missing for season #{year}; cannot expand full-season discovery"
              )
            )
          end
          private_class_method :unavailable_calendar
        end
      end
    end
  end
end
