# frozen_string_literal: true

module Jumbotron
  module Workflows
    module Sandbox
      class RegisterProjectionWorkflow < CommandTower::Workflows::ApplicationWorkflow
        include Jumbotron::Workflows::PublicRead

        retry_strategy :none

        def call(**kwargs)
          deserialized = Jumbotron::Deserializers::Public::RegisterSandboxProjection.call(kwargs)
          return map_deserializer_failure(deserialized) unless deserialized.success?

          transaction do
            registered = Jumbotron::Services::Sandbox::RegisterProjection.call(request: deserialized.input)
            fail_transaction!(map_service_failure(registered)) unless registered.success?

            assembled = Jumbotron::Services::Public::AssembleSandboxProjection.call(
              projection: registered.data[:projection]
            )
            fail_transaction!(map_service_failure(assembled)) unless assembled.success?

            success(
              payload: { sandbox_projection: assembled.data[:public_projection] },
              http_status: :ok
            )
          end
        end
      end
    end
  end
end
