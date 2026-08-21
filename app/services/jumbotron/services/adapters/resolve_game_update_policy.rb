# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class ResolveGameUpdatePolicy < CommandTower::Services::ApplicationService
        UPDATE_POLICY_TYPES = %i[
          future_game_update
          live_game_update
          interrupted_game_update
        ].freeze

        validate :adapter_id, required: true
        validate :policy_id, required: true

        def call
          Jumbotron::Adapters::Registry.ensure_loaded!
          adapter = Jumbotron::Adapters::Registry.find(adapter_id)
          if adapter.nil?
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::UnknownAdapterError.new(
                details: { adapter_id: adapter_id }
              )
            )
            return
          end

          unless adapter.registered?
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::NotRegisteredError.new(
                details: { adapter: adapter.to_s }
              )
            )
            return
          end

          key = policy_id.to_sym
          if adapter.discovery_ids.include?(key)
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::DiscoveryNotExecutableError.new(
                details: { policy_id: policy_id }
              )
            )
            return
          end

          policy = lookup_policy(adapter, key)
          return if policy.nil?

          unless UPDATE_POLICY_TYPES.include?(policy.type)
            context.fail!(application_error: Jumbotron::Errors::Adapters::InvalidPolicyTypeError.new)
            return
          end

          context.adapter = adapter
          context.policy = policy
        end

        private

        def lookup_policy(adapter, key)
          adapter.policy(key)
        rescue Jumbotron::Adapters::UnknownPolicyError
          context.fail!(
            application_error: Jumbotron::Errors::Adapters::UnknownPolicyError.new(
              details: { policy_id: policy_id }
            )
          )
          nil
        end
      end
    end
  end
end
