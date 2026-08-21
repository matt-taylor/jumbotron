# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class ResolveDiscovery < CommandTower::Services::ApplicationService
        validate :adapter_id, required: true
        validate :discovery_id, required: true

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

          definition = lookup_discovery(adapter)
          return if definition.nil?

          context.adapter = adapter
          context.definition = definition
        end

        private

        def lookup_discovery(adapter)
          adapter.discovery(discovery_id.to_sym)
        rescue Jumbotron::Adapters::UnknownDiscoveryError
          context.fail!(
            application_error: Jumbotron::Errors::Adapters::UnknownDiscoveryError.new(
              details: { discovery_id: discovery_id }
            )
          )
          nil
        end
      end
    end
  end
end
