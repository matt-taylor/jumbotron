# frozen_string_literal: true

module Jumbotron
  class LineUpdateJob < ApplicationJob
    def perform(adapter_id:, policy_id:)
      Workflows::ExecuteLineUpdatePolicyWorkflow.call_from_job(
        adapter_id: adapter_id,
        policy_id: policy_id
      )
    end
  end
end
