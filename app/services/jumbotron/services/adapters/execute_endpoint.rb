# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class ExecuteEndpoint < CommandTower::Services::ApplicationService
        validate :adapter, required: true
        validate :endpoint, required: true
        validate :observed_at, required: true
        validate :acquisition, is_a: Hash, required: false

        def call
          operation = adapter.operation(endpoint)
          provider_result = operation.acquire(**(acquisition || {}))
          unless provider_result.success?
            fail_acquisition!(provider_result)
            return
          end

          begin
            context.sync_input = operation.transform(provider_result.output, observed_at: observed_at)
          rescue Jumbotron::Adapters::TransformError => e
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::NormalizationFailedError.new(
                details: { message: e.message }
              )
            )
          end
        end

        private

        def fail_acquisition!(provider_result)
          error = provider_result.error
          if error.is_a?(Jumbotron::Providers::Espn::CooldownActiveError)
            context.fail!(application_error: Jumbotron::Errors::Adapters::ProviderCooldownActiveError.new)
            return
          end

          context.fail!(
            application_error: Jumbotron::Errors::Adapters::AcquisitionFailedError.new(
              details: { message: error&.message || "provider acquisition failed" }
            )
          )
        end
      end
    end
  end
end
