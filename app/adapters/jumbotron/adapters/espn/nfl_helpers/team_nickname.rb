# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        # Maps ESPN team identity fields into canonical nickname without parsing display_name.
        # Precedence: nickname → name → short_display_name (provider fields only).
        module TeamNickname
          def self.resolve(team)
            return nil if team.nil?

            team.nickname.presence || team.name.presence || team.short_display_name.presence
          end
        end
      end
    end
  end
end
