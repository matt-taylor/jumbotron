# frozen_string_literal: true

module Jumbotron
  module Scheduling
    class UnsupportedIntegrationError < StandardError; end

    module DetectIntegration
      SUPPORTED = "Solid Queue, Sidekiq + Sidekiq-Cron"

      module_function

      def call
        name = adapter_name
        return Backends::SolidQueue.new if name == :solid_queue
        return sidekiq_backend! if name == :sidekiq

        raise_unsupported(name)
      end

      def adapter_name
        return ActiveJob::Base.queue_adapter_name.to_s.to_sym if ActiveJob::Base.respond_to?(:queue_adapter_name)

        configured = Rails.application.config.active_job.queue_adapter
        return configured.to_sym if configured.is_a?(Symbol)

        ActiveJob::Base.queue_adapter.class.name.to_s.demodulize.underscore.sub(/_adapter\z/, "").to_sym
      end

      def sidekiq_backend!
        return Backends::SidekiqCron.new if defined?(::Sidekiq::Cron::Job)

        raise UnsupportedIntegrationError,
              "Jumbotron recurring schedules cannot be materialized for ActiveJob adapter :sidekiq " \
              "because no supported recurring scheduler is present. " \
              "Supported scheduling integrations: #{SUPPORTED}."
      end

      def raise_unsupported(name)
        raise UnsupportedIntegrationError,
              "Jumbotron recurring schedules cannot be materialized for ActiveJob adapter :#{name}. " \
              "Supported scheduling integrations: #{SUPPORTED}."
      end
    end
  end
end
