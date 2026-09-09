# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      class SandboxProjection < CommandTower::Deserializers::ApplicationDeserializer
        def call(params)
          name = unwrap(fetch_param(params, :name))
          return name if deserializer_result?(name)
          return failure(errors: [{ code: "invalid_request", message: "name is required" }]) if name.blank?

          success(Jumbotron::Public::SandboxProjectionRequest.new(name: name.to_s))
        end
      end
    end
  end
end
