# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      # Isolates lease + existing SynchronizeAdapterWorkflow.call. The workflow-calls-workflow
      # rule remains deferred; do not invent a SharedSequence here.
      class ExecuteSynchronizationScope < CommandTower::Services::ApplicationService
        validate :adapter, required: true
        validate :league, required: true
        validate :endpoint, required: true
        validate :acquisition, is_a: Hash, required: true

        def call
          lease = Synchronization::Lease.new
          lease_scope = Synchronization::Lease.scope(
            adapter_id: adapter.adapter_id,
            endpoint: endpoint,
            acquisition: acquisition
          )
          held = lease.acquire(lease_scope)
          unless held.acquired?
            context.outcome = :contention
            return
          end

          begin
            record_sync_outcome(
              Workflows::SynchronizeAdapterWorkflow.call(
                adapter: adapter,
                endpoint: endpoint,
                league_id: league.id,
                acquisition: acquisition
              )
            )
          ensure
            lease.release(lease_scope, token: held.token)
          end
        end

        private

        def record_sync_outcome(result)
          if result.success?
            context.outcome = :succeeded
            return
          end

          code = Array(result.errors).first
          code = code[:code] if code.is_a?(Hash)
          code = code.code if code.respond_to?(:code)

          if code.to_s == "provider_cooldown_active"
            context.outcome = :cooldown_active
            return
          end

          context.outcome = :failed
          context.failure_class = result.meta[:failure_class]
        end
      end
    end
  end
end
