# frozen_string_literal: true

module Jumbotron
  module SpecSupport
    class FakeSidekiqCronJob
      Job = Struct.new(:name, :klass, :cron, :args, keyword_init: true) do
        def destroy
          FakeSidekiqCronJob.registry.delete(name)
        end
      end

      class << self
        attr_accessor :registry

        def reset!
          self.registry = {}
        end

        def all
          registry.values
        end

        def create(attrs)
          attrs = attrs.transform_keys(&:to_s)
          job = Job.new(
            name: attrs.fetch("name"),
            klass: attrs["class"],
            cron: attrs["cron"],
            args: attrs["args"]
          )
          registry[job.name] = job
          job
        end
      end
    end
  end
end

Jumbotron::SpecSupport::FakeSidekiqCronJob.reset!
