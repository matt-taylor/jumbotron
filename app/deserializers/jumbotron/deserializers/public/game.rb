# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      class Game < CommandTower::Deserializers::ApplicationDeserializer
        def call(params)
          id_raw = unwrap(fetch_param(params, :id))
          return id_raw if deserializer_result?(id_raw)
          return failure(errors: [{ code: "invalid_request", message: "id is required" }]) if id_raw.nil?

          id = unwrap(require_integer(id_raw, field: "id", min: 1))
          return id if deserializer_result?(id)

          include_raw = unwrap(fetch_param(params, :include))
          return include_raw if deserializer_result?(include_raw)

          includes = unwrap(Includes.parse(include_raw))
          return includes if deserializer_result?(includes)

          success(Jumbotron::Public::GameRequest.new(id: id, includes: includes))
        end
      end
    end
  end
end
