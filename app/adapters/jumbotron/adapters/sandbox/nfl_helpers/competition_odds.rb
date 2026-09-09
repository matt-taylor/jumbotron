# frozen_string_literal: true

require "bigdecimal"

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        class CompetitionOdds
          BOOKMAKER_ID = "synthetic-consensus"
          BOOKMAKER_NAME = "Sandbox Sportsbook"

          def self.call(payload, observed_at:, acquisition:) # rubocop:disable Metrics/MethodLength
            event_id, competition_id = identity_values(payload, acquisition)
            values = payload.symbolize_keys.reverse_merge(acquisition.symbolize_keys)

            Canonical::LineIngestInput.new(
              observed_at: observed_at,
              provider: "sandbox",
              adapter_scope: "sandbox_nfl",
              game_identities: game_identities(event_id, competition_id),
              observations: observations(
                home_spread: BigDecimal(values.fetch(:home_spread).to_s),
                total: BigDecimal(values.fetch(:total).to_s)
              )
            )
          rescue ArgumentError, KeyError => e
            raise TransformError, "invalid sandbox line observation: #{e.message}"
          end

          def self.identity_values(payload, acquisition)
            data = payload.symbolize_keys
            scope = acquisition.symbolize_keys
            event_id = data[:event_id].presence || scope.fetch(:event_id)
            [event_id, data[:competition_id].presence || scope[:competition_id] || event_id]
          end
          private_class_method :identity_values

          def self.game_identities(event_id, competition_id)
            [
              Canonical::ProviderIdentityRef.new(provider: "sandbox", namespace: "event", id: event_id.to_s),
              Canonical::ProviderIdentityRef.new(
                provider: "sandbox",
                namespace: "competition",
                id: competition_id.to_s
              )
            ]
          end
          private_class_method :game_identities

          def self.observations(home_spread:, total:) # rubocop:disable Metrics/MethodLength
            identity = Canonical::ProviderIdentityRef.new(
              provider: "sandbox",
              namespace: "bookmaker",
              id: BOOKMAKER_ID
            )
            [
              line(identity, "spread", "home", home_spread),
              line(identity, "spread", "away", -home_spread),
              line(identity, "total", "over", total),
              line(identity, "total", "under", total)
            ]
          end
          private_class_method :observations

          def self.line(identity, market, outcome, value)
            Canonical::LineObservationInput.new(
              bookmaker_identity: identity,
              bookmaker_name: BOOKMAKER_NAME,
              market: market,
              outcome: outcome,
              source: "observed",
              line_value: BigDecimal(value.to_s),
              price_american: -110
            )
          end
          private_class_method :line
        end
      end
    end
  end
end
