# frozen_string_literal: true

module Jumbotron
  class DiscoveryJob < ApplicationJob
    def perform(adapter_id:, discovery_id:, continuation_attempt: 1)
      execute_workflow(
        Workflows::ExecuteDiscoveryWorkflow,
        adapter_id: adapter_id,
        discovery_id: discovery_id,
        continuation_attempt: continuation_attempt
      )
    end
  end
end
