# frozen_string_literal: true

module Jumbotron
  module Scheduling
    ScheduleDefinition = Data.define(:id, :job_class_name, :arguments, :cadence)
  end
end
