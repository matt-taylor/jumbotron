# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        module SeasonPhase
          MAP = {
            1 => "preseason",
            2 => "regular_season",
            3 => "postseason",
            4 => "offseason"
          }.freeze

          module_function

          def call(season_type)
            mapped = MAP[season_type.to_i]
            raise TransformError, "unsupported ESPN season.type: #{season_type.inspect}" if mapped.nil?

            mapped
          end

          def espn_season_type(phase_key)
            return if phase_key.nil?

            MAP.key(phase_key.to_s)
          end
        end
      end
    end
  end
end
