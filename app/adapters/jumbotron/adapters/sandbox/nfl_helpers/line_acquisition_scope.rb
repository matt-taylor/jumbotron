# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module LineAcquisitionScope
          module_function

          def call(game) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
            identities = game.provider_identities.index_by(&:object_namespace)
            event = identities["event"]
            mapping = game.sandbox_game_mapping
            return if event.nil? || event.provider != "sandbox" || event.provider_id.blank? || mapping.nil?

            {
              endpoint: :competition_odds,
              acquisition: {
                event_id: event.provider_id,
                competition_id: identities["competition"]&.provider_id || event.provider_id,
                home_spread: mapping.home_spread.to_s,
                total: mapping.total.to_s
              }
            }
          end
        end
      end
    end
  end
end
