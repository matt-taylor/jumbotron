# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ExecuteDiscoveryWorkflow < CommandTower::Workflows::ApplicationWorkflow
      retry_strategy :delayed_continuation, max_attempts: 24

      CONTENTION_WAIT_SECONDS = 5

      def call(adapter_id:, discovery_id:)
        resolved = Services::Adapters::ResolveDiscovery.call(
          adapter_id: adapter_id,
          discovery_id: discovery_id
        )
        return map_resolution_failure(resolved) unless resolved.success?

        adapter = resolved.data[:adapter]
        definition = resolved.data[:definition]
        ensured = Services::Adapters::EnsureLeague.call(adapter: adapter)
        return map_resolution_failure(ensured) unless ensured.success?

        league = ensured.data[:league]
        return cooldown_deferred(adapter) if adapter.provider_cooling_down?

        expanded = adapter.scopes_for_discovery(definition)
        return map_expand_failure(adapter, expanded) unless expanded.success?

        scopes = Array(expanded.output).map do |acquisition|
          { endpoint: definition.endpoint, acquisition: acquisition }
        end
        return empty_scopes_failure(adapter, definition) if scopes.empty?

        run_scopes(adapter, league, scopes, discovery_id)
      end

      private

      def run_scopes(adapter, league, scopes, discovery_id)
        scopes.each do |scope|
          return cooldown_deferred(adapter) if adapter.provider_cooling_down?

          executed = Services::Adapters::ExecuteSynchronizationScope.call(
            adapter: adapter,
            league: league,
            endpoint: scope.fetch(:endpoint),
            acquisition: scope.fetch(:acquisition)
          )
          classified = classify_scope(adapter, executed)
          return classified unless classified.nil?
        end

        success(
          payload: { adapter_id: adapter.adapter_id, discovery_id: discovery_id.to_s },
          http_status: :ok
        )
      end

      def classify_scope(adapter, executed)
        unless executed.success?
          return failure(
            errors: [{ code: "discovery_execution_failed", message: "synchronization scope failed" }],
            http_status: :unprocessable_entity,
            meta: { failure_class: "mutation" }
          )
        end

        data = executed.data
        case data[:outcome]
        when :succeeded
          nil
        when :contention
          deferred(reason: :lease_contention, retry_after: CONTENTION_WAIT_SECONDS)
        when :cooldown_active
          cooldown_deferred(adapter)
        else
          classify_failed_scope(adapter, data)
        end
      end

      def classify_failed_scope(adapter, data)
        return cooldown_deferred(adapter) if data[:failure_class] == "acquisition"

        failure(
          errors: [{ code: "discovery_execution_failed", message: "canonical or transform failure" }],
          http_status: :unprocessable_entity,
          meta: { failure_class: data[:failure_class] || "mutation" }
        )
      end

      def map_expand_failure(adapter, expanded)
        return cooldown_deferred(adapter) if adapter.provider_cooling_down?

        error = expanded.respond_to?(:error) ? expanded.error : nil
        failure(
          errors: [{
            code: "discovery_expansion_failed",
            message: error.respond_to?(:message) ? error.message : "discovery expansion failed"
          }],
          http_status: :unprocessable_entity,
          meta: { failure_class: "validation" }
        )
      end

      def empty_scopes_failure(adapter, definition)
        failure(
          errors: [{
            code: "discovery_expansion_failed",
            message: "discovery #{definition.id} produced no acquisition scopes"
          }],
          http_status: :unprocessable_entity,
          meta: { failure_class: "validation", adapter_id: adapter.adapter_id }
        )
      end

      def cooldown_deferred(adapter)
        wait = [Integer(adapter.provider_retry_after), 1].max
        deferred(reason: :provider_cooldown, retry_after: wait)
      end

      def map_resolution_failure(result)
        error = Array(result.errors).first
        code = error.respond_to?(:code) ? error.code : "unknown_adapter"
        failure(
          errors: [{ code: code, message: error.respond_to?(:message) ? error.message : error.to_s }],
          http_status: :unprocessable_entity,
          meta: { failure_class: "validation" }
        )
      end
    end
  end
end
