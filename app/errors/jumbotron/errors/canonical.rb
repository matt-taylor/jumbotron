# frozen_string_literal: true

module Jumbotron
  module Errors
    module Canonical
      class InvalidSyncInputError < CommandTower::Errors::ApplicationError
        def code
          "invalid_sync_input"
        end

        def message
          "canonical input must be Canonical::SyncInput"
        end
      end

      class ProviderIdentityConflictError < CommandTower::Errors::ApplicationError
        def code
          "provider_identity_conflict"
        end

        def message
          "provider identity is already attached to a different target"
        end
      end

      class MutationFailedError < CommandTower::Errors::ApplicationError
        def code
          "mutation_failed"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "canonical mutation failed"
        end
      end

      class InvalidLineIngestError < CommandTower::Errors::ApplicationError
        def code
          "invalid_line_ingest"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "invalid line ingest"
        end
      end

      class GameNotFoundError < CommandTower::Errors::ApplicationError
        def code
          "game_not_found"
        end

        def message
          "canonical game was not found for the provided identities"
        end
      end

      class ObservationEvidenceFailedError < CommandTower::Errors::ApplicationError
        def code
          "observation_evidence_failed"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "observation evidence failed"
        end
      end
    end
  end
end
