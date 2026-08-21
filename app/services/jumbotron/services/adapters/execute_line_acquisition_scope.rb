# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class ExecuteLineAcquisitionScope < CommandTower::Services::ApplicationService
        validate :adapter, required: true
        validate :acquisition, is_a: Hash, required: true

        def call
          if adapter.provider_cooling_down?
            context.outcome = :cooldown_active
            return
          end

          lease = Synchronization::Lease.new
          lease_scope = Synchronization::Lease.scope(
            adapter_id: adapter.adapter_id,
            endpoint: :competition_odds,
            acquisition: acquisition
          )
          held = lease.acquire(lease_scope)
          unless held.acquired?
            context.outcome = :contention
            return
          end

          begin
            execute_held
          ensure
            lease.release(lease_scope, token: held.token)
          end
        end

        private

        def execute_held
          provider_result = adapter.acquire_line_odds(acquisition)
          unless provider_result.success?
            record_acquisition_failure(provider_result)
            return
          end

          ingest = adapter.translate_line_odds(
            provider_result.output,
            observed_at: Time.current,
            acquisition: acquisition
          )
          persisted = Canonical::PersistLineObservations.call(ingest: ingest)
          unless persisted.success?
            context.outcome = :failed
            context.failure_class = "mutation"
            return
          end

          context.outcome = :succeeded
        rescue Jumbotron::Adapters::TransformError
          context.outcome = :failed
          context.failure_class = "mutation"
        end

        def record_acquisition_failure(provider_result)
          error = provider_result.error
          if error.is_a?(Jumbotron::Providers::Espn::CooldownActiveError)
            context.outcome = :cooldown_active
            return
          end

          context.outcome = :failed
          context.failure_class = "acquisition"
        end
      end
    end
  end
end
