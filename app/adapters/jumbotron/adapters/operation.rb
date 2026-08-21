# frozen_string_literal: true

module Jumbotron
  module Adapters
    class Operation
      attr_reader :adapter, :resource, :transformer

      def initialize(adapter:, resource:, transformer:)
        @adapter = adapter
        @resource = resource
        @transformer = transformer
      end

      def acquire(**query)
        resource.acquire(adapter: adapter, **query)
      end

      def transform(typed_payload, observed_at:)
        transformer.call(typed_payload, observed_at: observed_at)
      end
    end
  end
end
