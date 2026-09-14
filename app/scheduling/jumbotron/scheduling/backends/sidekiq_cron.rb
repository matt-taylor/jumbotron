# frozen_string_literal: true

module Jumbotron
  module Scheduling
    module Backends
      class SidekiqCron
        def initialize(job_class: nil)
          @job_class = job_class
        end

        def materialize(schedules, **)
          klass = job_class
          applicable = sidekiq_expressible(schedules)
          remove_stale(klass, applicable)
          upsert_desired(klass, applicable)
        end

        def cron_string(cadence)
          Clock.cron(cadence)
        end

        private

        # Five-field cron cannot express sub-minute cadences (Solid Queue / fugit can).
        def sidekiq_expressible(schedules)
          schedules.reject { |definition| second_unit?(definition.cadence.unit) }
        end

        def second_unit?(unit)
          Clock.canonical_unit(unit) == :second
        end

        def remove_stale(klass, schedules)
          desired_ids = schedules.map(&:id)
          Array(klass.all).each do |job|
            name = job_name(job)
            next unless Owned.key?(name)
            next if desired_ids.include?(name)

            destroy_job(klass, name, job)
          end
        end

        def upsert_desired(klass, schedules)
          schedules.sort_by(&:id).each do |definition|
            klass.create(
              "name" => definition.id,
              "class" => definition.job_class_name,
              "cron" => cron_string(definition.cadence),
              "args" => [definition.arguments]
            )
          end
        end

        def job_class
          @job_class || (defined?(::Sidekiq::Cron::Job) && ::Sidekiq::Cron::Job) ||
            raise(UnsupportedIntegrationError, "Sidekiq::Cron::Job is not available")
        end

        def job_name(job)
          if job.respond_to?(:name)
            job.name
          elsif job.is_a?(Hash)
            job[:name] || job["name"]
          else
            job.to_s
          end
        end

        def destroy_job(klass, name, job)
          if job.respond_to?(:destroy)
            job.destroy
          elsif klass.respond_to?(:destroy)
            klass.destroy(name)
          end
        end
      end
    end
  end
end
