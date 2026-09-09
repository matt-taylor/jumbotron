# frozen_string_literal: true

module Jumbotron
  module Workflows
    module Sandbox
      class ReadProjectionWorkflow < CommandTower::Workflows::ApplicationWorkflow
        include Jumbotron::Workflows::PublicRead

        retry_strategy :none

        def call(**kwargs)
          deserialized = Jumbotron::Deserializers::Public::SandboxProjection.call(kwargs)
          return map_deserializer_failure(deserialized) unless deserialized.success?

          read = Jumbotron::Services::Public::ReadSandboxProjection.call(name: deserialized.input.name)
          return map_service_failure(read) unless read.success?

          assembled = Jumbotron::Services::Public::AssembleSandboxProjection.call(
            projection: read.data[:projection]
          )
          return map_service_failure(assembled) unless assembled.success?

          success(payload: { sandbox_projection: assembled.data[:public_projection] }, http_status: :ok)
        end
      end
    end
  end
end
