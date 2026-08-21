# frozen_string_literal: true

module Jumbotron
  module Boot
    module EnqueueDiscoveries
      module_function

      def call
        return unless eligible?

        enqueue!
      end

      def eligible?
        return false unless Jumbotron::Engine.config.boot_discovery
        return false if Rails.env.test?
        return false if defined?(Rails::Console)
        return false if rake_environment?

        true
      end

      def enqueue!
        Jumbotron::Scheduling::DesiredSchedules.ensure_adapters_loaded!
        Jumbotron::Adapters::Registry.registered.each do |adapter|
          adapter.discovery_ids.each do |discovery_id|
            Jumbotron::DiscoveryJob.perform_later(
              adapter_id: adapter.adapter_id,
              discovery_id: discovery_id.to_s,
              continuation_attempt: 1
            )
          end
        end
      end

      def rake_environment?
        defined?(Rake) && Rake.respond_to?(:application) && Array(Rake.application.top_level_tasks).any?
      end
    end
  end
end
