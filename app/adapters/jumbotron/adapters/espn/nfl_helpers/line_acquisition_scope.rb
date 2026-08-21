# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        module LineAcquisitionScope
          module_function

          def call(game)
            identities = Array(game.provider_identities)
            event = identities.find { |identity| identity.object_namespace == "event" }
            competition = identities.find { |identity| identity.object_namespace == "competition" }
            return if event.nil? || event.provider_id.blank?

            competition_id = competition&.provider_id.presence || event.provider_id
            {
              endpoint: :competition_odds,
              acquisition: { event_id: event.provider_id, competition_id: competition_id }
            }
          end
        end
      end
    end
  end
end
