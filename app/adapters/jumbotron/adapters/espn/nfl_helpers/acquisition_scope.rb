# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        module AcquisitionScope
          module_function

          def call(game)
            group = game.schedule_group
            return if group.nil? || group.kind != "week" || group.number.nil?

            year = Integer(game.season.name)
            season_type = SeasonPhase.espn_season_type(game.season_phase&.name)
            return if season_type.nil?

            {
              endpoint: :scoreboard,
              acquisition: { dates: year, season_type: season_type, week: group.number }
            }
          rescue ArgumentError, TypeError
            nil
          end
        end
      end
    end
  end
end
