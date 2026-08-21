# frozen_string_literal: true

require "pathname"

module Jumbotron
  module Adapters
    module Registry
      module_function

      # Stores the adapter class reference (not a config snapshot).
      # Top-of-class register! is safe: identity is the class, not registry_key.
      def register(adapter_class)
        classes[adapter_class.name] = adapter_class
        adapter_class
      end

      def registered
        classes.values
      end

      def registered?(adapter_class)
        classes[adapter_class.name] == adapter_class
      end

      # Adapter classes register via load-time `register!`. In non-eager-load
      # processes (e.g. Solid Queue workers), nothing may have constantized them
      # yet when jobs resolve by adapter_id string — load them first.
      # If classes are already loaded but the in-memory registry was cleared,
      # re-register Base subclasses (constantize alone does not re-run file side effects).
      def ensure_loaded!
        Dir[Jumbotron::Engine.root.join("app/adapters/jumbotron/adapters/**/*.rb")].each do |path|
          relative = Pathname.new(path).relative_path_from(Jumbotron::Engine.root.join("app/adapters")).to_s
          klass = relative.chomp(".rb").camelize.constantize
          next unless klass.is_a?(Class)
          next unless klass < Base
          next if klass == Base

          klass.register! unless registered?(klass)
        end
      end

      def find(adapter_id)
        id = adapter_id.to_s
        registered.find do |adapter|
          adapter.adapter_id == id
        rescue ConfigurationError
          false
        end
      end

      def reset!
        @classes = {}
      end

      # Raises if two different registered classes share the same registry_key.
      def assert_unique_keys!
        grouped = registered.group_by do |adapter|
          adapter.registry_key
        rescue ConfigurationError
          :incomplete
        end
        grouped.each do |key, adapters|
          next if key == :incomplete
          next if adapters.uniq.size <= 1

          raise RegistrationError,
                "conflicting adapter registration for #{key.inspect}: " \
                "#{adapters.map(&:name).join(' vs ')}"
        end
      end

      def classes
        @classes ||= {}
      end
      private_class_method :classes
    end
  end
end
