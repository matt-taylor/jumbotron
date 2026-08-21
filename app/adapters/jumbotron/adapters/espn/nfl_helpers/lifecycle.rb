# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        module Lifecycle
          MAP = {
            "STATUS_SCHEDULED" => "scheduled",
            "STATUS_IN_PROGRESS" => "in_progress",
            "STATUS_FINAL" => "completed",
            "STATUS_POSTPONED" => "postponed",
            "STATUS_CANCELED" => "cancelled",
            "STATUS_CANCELLED" => "cancelled"
          }.freeze

          module_function

          def call(type_name)
            key = type_name.to_s
            mapped = MAP[key]
            raise TransformError, "unsupported ESPN status: #{key.inspect}" if mapped.nil?

            mapped
          end
        end
      end
    end
  end
end
