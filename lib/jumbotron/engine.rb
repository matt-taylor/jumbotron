# frozen_string_literal: true

module Jumbotron
  class Engine < ::Rails::Engine
    isolate_namespace Jumbotron

    # Ensure app/synchronization is on Zeitwerk paths (alongside adapters/clients/providers).
    config.autoload_paths << root.join("app/synchronization")
    config.eager_load_paths << root.join("app/synchronization")
    config.autoload_paths << root.join("app/scheduling")
    config.eager_load_paths << root.join("app/scheduling")

    config.autoload_paths << root.join("app/boot")
    config.eager_load_paths << root.join("app/boot")

    config.boot_discovery = true

    # Reconcile jumbotron:* Sidekiq-Cron jobs on Sidekiq server start only.
    # Do not require Sidekiq; skip when the host has not loaded Sidekiq-Cron.
    config.after_initialize do
      Jumbotron::Boot::EnqueueDiscoveries.call

      next unless defined?(::Sidekiq) && defined?(::Sidekiq::Cron::Job)

      ::Sidekiq.configure_server do |sidekiq|
        sidekiq.on(:startup) do
          Jumbotron::Scheduling::Materializer.call
        end
      end
    end
  end
end
