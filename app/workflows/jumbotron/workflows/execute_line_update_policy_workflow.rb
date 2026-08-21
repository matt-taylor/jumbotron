# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ExecuteLineUpdatePolicyWorkflow < CommandTower::Workflows::ApplicationWorkflow
      retry_strategy :scheduled_cadence

      def call(adapter_id:, policy_id:)
        now = Time.current
        resolved = Services::Adapters::ResolveLineUpdatePolicy.call(
          adapter_id: adapter_id,
          policy_id: policy_id
        )
        return map_resolution_failure(resolved) unless resolved.success?

        adapter = resolved.data[:adapter]
        policy = resolved.data[:policy]
        selected = Services::Adapters::SelectEligibleGames.call(
          adapter: adapter,
          policy: policy,
          now: now
        )
        return map_selection_failure(selected) unless selected.success?

        games = selected.data[:games]
        built = Services::Adapters::BuildLineAcquisitionScopes.call(adapter: adapter, games: games)
        return map_selection_failure(built) unless built.success?

        scopes = built.data[:scopes]
        counts = blank_counts.merge(
          eligible_games: games.size,
          unique_scopes: scopes.size,
          skipped_incomplete_scope: built.data[:skipped_incomplete_scope]
        )

        return success_payload(adapter, policy, counts) if scopes.empty?

        run_scopes(adapter, scopes, counts)
        finish(adapter, policy, counts)
      end

      private

      def run_scopes(adapter, scopes, counts)
        scopes.each_with_index do |scope, index|
          if adapter.provider_cooling_down?
            counts[:skipped_cooldown] += scopes.size - index
            break
          end

          handle_scope(adapter, scope, counts)
          next unless counts[:stop_remaining]

          remaining = scopes.size - index - 1
          counts[:skipped_cooldown] += remaining if remaining.positive?
          break
        end
        counts.delete(:stop_remaining)
      end

      def handle_scope(adapter, scope, counts)
        executed = Services::Adapters::ExecuteLineAcquisitionScope.call(
          adapter: adapter,
          acquisition: scope.fetch(:acquisition)
        )
        unless executed.success?
          counts[:failed_scopes] += 1
          counts[:failure_class] ||= "mutation"
          return
        end

        record_scope_outcome(executed.data, counts)
      end

      def record_scope_outcome(data, counts)
        case data[:outcome]
        when :succeeded
          counts[:succeeded_scopes] += 1
        when :contention
          counts[:skipped_contention] += 1
        when :cooldown_active
          counts[:skipped_cooldown] += 1
          counts[:stop_remaining] = true
        else
          counts[:failed_scopes] += 1
          counts[:failure_class] ||= data[:failure_class]
          counts[:stop_remaining] = true if data[:failure_class] == "acquisition"
        end
      end

      def finish(adapter, policy, counts)
        payload = result_payload(adapter, policy, counts)
        if counts[:failed_scopes].positive?
          return failure(
            errors: [{ code: "policy_execution_failed", message: "one or more scopes failed" }],
            http_status: counts[:failure_class] == "acquisition" ? :bad_gateway : :unprocessable_entity,
            meta: { failure_class: counts[:failure_class] || "mutation", execution: payload }
          )
        end

        success(payload: payload, http_status: :ok)
      end

      def success_payload(adapter, policy, counts)
        success(payload: result_payload(adapter, policy, counts), http_status: :ok)
      end

      def result_payload(adapter, policy, counts)
        {
          adapter_id: adapter.adapter_id,
          policy_id: policy.id.to_s,
          eligible_games: counts[:eligible_games],
          unique_scopes: counts[:unique_scopes],
          succeeded_scopes: counts[:succeeded_scopes],
          skipped_contention: counts[:skipped_contention],
          skipped_cooldown: counts[:skipped_cooldown],
          skipped_incomplete_scope: counts[:skipped_incomplete_scope],
          failed_scopes: counts[:failed_scopes]
        }
      end

      def blank_counts
        {
          succeeded_scopes: 0,
          skipped_contention: 0,
          skipped_cooldown: 0,
          skipped_incomplete_scope: 0,
          failed_scopes: 0
        }
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

      def map_selection_failure(result)
        error = Array(result.errors).first
        if error.is_a?(CommandTower::Errors::ApplicationError)
          return failure(
            errors: [error],
            http_status: :unprocessable_entity,
            meta: { failure_class: "validation" }
          )
        end

        map_resolution_failure(result)
      end
    end
  end
end
