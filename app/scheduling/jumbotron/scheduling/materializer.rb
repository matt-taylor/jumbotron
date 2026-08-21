# frozen_string_literal: true

module Jumbotron
  module Scheduling
    class Materializer
      def self.call(schedules: nil, backend: nil, solid_queue_path: nil)
        schedules ||= DesiredSchedules.call
        backend ||= DetectIntegration.call
        backend.materialize(schedules, path: solid_queue_path)
      end
    end
  end
end
