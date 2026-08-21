# frozen_string_literal: true

module Jumbotron
  module Scheduling
    module DesiredSchedules
      GAME_JOB_CLASS_NAME = "Jumbotron::GameUpdateJob"
      LINE_JOB_CLASS_NAME = "Jumbotron::LineUpdateJob"

      module_function

      def call
        ensure_adapters_loaded!
        Adapters::Registry.registered.flat_map { |adapter| schedules_for(adapter) }
      end

      def schedules_for(adapter)
        adapter.policies.values.filter_map { |policy| definition_for(adapter, policy) }
      end

      def definition_for(adapter, policy)
        return if adapter.discovery_ids.include?(policy.id)
        return if policy.cadence.nil?

        job_class_name = job_class_name_for(policy)
        return if job_class_name.nil?

        ScheduleDefinition.new(
          id: Owned.id(adapter.adapter_id, policy.id),
          job_class_name: job_class_name,
          arguments: {
            "adapter_id" => adapter.adapter_id.to_s,
            "policy_id" => policy.id.to_s
          },
          cadence: policy.cadence
        )
      end

      def job_class_name_for(policy)
        if Services::Adapters::ResolveGameUpdatePolicy::UPDATE_POLICY_TYPES.include?(policy.type)
          GAME_JOB_CLASS_NAME
        elsif Services::Adapters::ResolveLineUpdatePolicy::LINE_POLICY_TYPES.include?(policy.type)
          LINE_JOB_CLASS_NAME
        end
      end

      def ensure_adapters_loaded!
        Adapters::Registry.ensure_loaded!
      end
    end
  end
end
