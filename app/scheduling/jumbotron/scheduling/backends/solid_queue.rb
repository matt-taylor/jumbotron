# frozen_string_literal: true

require "fileutils"
require "pathname"
require "yaml"

module Jumbotron
  module Scheduling
    module Backends
      class SolidQueue
        ENV_SECTIONS = %w[development test production staging].freeze
        DEFAULT_RELATIVE = "config/recurring.yml"

        def initialize(path: nil)
          @explicit_path = path
        end

        def materialize(schedules, path: nil)
          destination = Pathname.new(path || @explicit_path || default_path)
          document = load_document(destination)
          section = current_section(document)
          section.delete_if { |key, _| Owned.key?(key) }
          schedules.sort_by(&:id).each do |definition|
            section[definition.id] = task_for(definition)
          end
          write_document(destination, document)
          destination
        end

        def schedule_string(cadence)
          Clock.fugit(cadence)
        end

        private

        def default_path
          ENV.fetch("SOLID_QUEUE_RECURRING_SCHEDULE") do
            ENV.fetch("JUMBOTRON_SOLID_QUEUE_RECURRING") do
              Rails.root.join(DEFAULT_RELATIVE).to_s
            end
          end
        end

        def load_document(destination)
          return {} unless destination.exist?

          loaded = YAML.safe_load_file(destination, permitted_classes: [Symbol], aliases: true)
          stringify_keys(loaded || {})
        end

        def current_section(document)
          if document.empty? || env_keyed?(document)
            document[Rails.env.to_s] ||= {}
          else
            document
          end
        end

        def env_keyed?(document)
          document.is_a?(Hash) && !document.empty? && document.keys.all? { |key| ENV_SECTIONS.include?(key.to_s) }
        end

        def task_for(definition)
          {
            "class" => definition.job_class_name,
            "args" => [definition.arguments],
            "schedule" => schedule_string(definition.cadence)
          }
        end

        def write_document(destination, document)
          FileUtils.mkdir_p(destination.dirname)
          header = "# jumbotron:* keys are managed by `bin/rails jumbotron:schedules:materialize`.\n"
          destination.write(header + YAML.dump(stringify_keys(document)))
        end

        def stringify_keys(value)
          case value
          when Hash
            value.each_with_object({}) do |(key, nested), memo|
              memo[key.to_s] = stringify_keys(nested)
            end
          when Array
            value.map { |item| stringify_keys(item) }
          else
            value
          end
        end
      end
    end
  end
end
