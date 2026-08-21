# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ReadScheduleGroupsWorkflow < CommandTower::Workflows::ApplicationWorkflow
      include PublicRead

      retry_strategy :none

      def call(**kwargs)
        deserialized = Deserializers::Public::ScheduleGroups.call(kwargs)
        return map_deserializer_failure(deserialized) unless deserialized.success?

        read = Services::Public::ReadScheduleGroups.call(request: deserialized.input)
        return map_service_failure(read) unless read.success?

        success(payload: { schedule_groups: read.data[:schedule_groups] }, http_status: :ok)
      end
    end
  end
end
