# frozen_string_literal: true

module Jumbotron
  class GameUpdateJob < ApplicationJob
    def perform(adapter_id:, policy_id:)
      Workflows::ExecuteGameUpdatePolicyWorkflow.call_from_job(
        adapter_id: adapter_id,
        policy_id: policy_id
      )
    end
  end
end
