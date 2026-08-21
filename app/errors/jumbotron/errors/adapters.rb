# frozen_string_literal: true

module Jumbotron
  module Errors
    module Adapters
      class InvalidAdapterError < CommandTower::Errors::ApplicationError
        def code
          "invalid_adapter"
        end

        def message
          "adapter is invalid"
        end
      end

      class NotRegisteredError < CommandTower::Errors::ApplicationError
        def code
          "adapter_not_registered"
        end

        def message
          adapter = details.is_a?(Hash) ? details[:adapter] : nil
          adapter ? "#{adapter} is not registered" : "adapter is not registered"
        end
      end

      class UnknownEndpointError < CommandTower::Errors::ApplicationError
        def code
          "unknown_endpoint"
        end

        def message
          endpoint = details.is_a?(Hash) ? details[:endpoint] : nil
          endpoint ? "adapter has no endpoint :#{endpoint}" : "unknown endpoint"
        end
      end

      class LeagueNotFoundError < CommandTower::Errors::ApplicationError
        def code
          "league_not_found"
        end

        def message
          league_id = details.is_a?(Hash) ? details[:league_id] : nil
          league_id ? "league #{league_id} not found" : "league not found"
        end
      end

      class AcquisitionFailedError < CommandTower::Errors::ApplicationError
        def code
          "acquisition_failed"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "provider acquisition failed"
        end
      end

      class NormalizationFailedError < CommandTower::Errors::ApplicationError
        def code
          "normalization_failed"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "normalization failed"
        end
      end

      class UnknownAdapterError < CommandTower::Errors::ApplicationError
        def code
          "unknown_adapter"
        end

        def message
          adapter_id = details.is_a?(Hash) ? details[:adapter_id] : nil
          adapter_id ? "unknown adapter #{adapter_id}" : "unknown adapter"
        end
      end

      class UnknownPolicyError < CommandTower::Errors::ApplicationError
        def code
          "unknown_policy"
        end

        def message
          policy_id = details.is_a?(Hash) ? details[:policy_id] : nil
          policy_id ? "unknown policy #{policy_id}" : "unknown policy"
        end
      end

      class DiscoveryNotExecutableError < CommandTower::Errors::ApplicationError
        def code
          "discovery_not_executable"
        end

        def message
          "discovery is not executable as a game-update policy"
        end
      end

      class UnknownDiscoveryError < CommandTower::Errors::ApplicationError
        def code
          "unknown_discovery"
        end

        def message
          discovery_id = details.is_a?(Hash) ? details[:discovery_id] : nil
          discovery_id ? "unknown discovery #{discovery_id}" : "unknown discovery"
        end
      end

      class InvalidPolicyTypeError < CommandTower::Errors::ApplicationError
        def code
          "invalid_policy_type"
        end

        def message
          "policy is not an executable game-update policy"
        end
      end

      class InvalidLinePolicyTypeError < CommandTower::Errors::ApplicationError
        def code
          "invalid_policy_type"
        end

        def message
          "policy is not an executable line-update policy"
        end
      end

      class ProviderCooldownActiveError < CommandTower::Errors::ApplicationError
        def code
          "provider_cooldown_active"
        end

        def message
          "provider cooldown is active"
        end
      end
    end
  end
end
