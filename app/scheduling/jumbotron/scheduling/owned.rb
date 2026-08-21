# frozen_string_literal: true

module Jumbotron
  module Scheduling
    module Owned
      PREFIX = "jumbotron:"

      module_function

      def key?(name)
        name.to_s.start_with?(PREFIX)
      end

      def id(adapter_id, policy_id)
        "#{PREFIX}#{adapter_id}:#{policy_id}"
      end
    end
  end
end
