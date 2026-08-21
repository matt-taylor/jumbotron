# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      class GameIds < CommandTower::Deserializers::ApplicationDeserializer
        def call(params)
          raw = unwrap(fetch_param(params, :game_ids))
          return raw if deserializer_result?(raw)
          return failure(errors: [{ code: "invalid_request", message: "game_ids is required" }]) if raw.nil?
          unless raw.is_a?(Array)
            return failure(errors: [{ code: "invalid_request", message: "game_ids must be an array" }])
          end

          ids = []
          raw.each do |item|
            coerced = unwrap(require_integer(item, field: "game_ids", min: 1))
            return coerced if deserializer_result?(coerced)

            ids << coerced
          end

          success(Jumbotron::Public::GameIdsRequest.new(game_ids: ids.uniq))
        end
      end
    end
  end
end
