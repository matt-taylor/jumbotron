# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      class Games < CommandTower::Deserializers::ApplicationDeserializer
        def call(params)
          raw = unwrap(fetch_param(params, :game_ids))
          return raw if deserializer_result?(raw)
          return failure(errors: [{ code: "invalid_request", message: "game_ids is required" }]) if raw.nil?
          unless raw.is_a?(Array)
            return failure(errors: [{ code: "invalid_request", message: "game_ids must be an array" }])
          end

          if raw.size > Jumbotron::Public::MAX_GAMES_IDS
            return failure(
              errors: [{
                code: "invalid_request",
                message: "game_ids exceeds maximum of #{Jumbotron::Public::MAX_GAMES_IDS}"
              }]
            )
          end

          ids = []
          raw.each do |item|
            coerced = unwrap(require_integer(item, field: "game_ids", min: 1))
            return coerced if deserializer_result?(coerced)

            ids << coerced
          end

          include_raw = unwrap(fetch_param(params, :include))
          return include_raw if deserializer_result?(include_raw)

          includes = unwrap(Includes.parse(include_raw))
          return includes if deserializer_result?(includes)

          success(Jumbotron::Public::GamesRequest.new(game_ids: ids.uniq, includes: includes))
        end
      end
    end
  end
end
