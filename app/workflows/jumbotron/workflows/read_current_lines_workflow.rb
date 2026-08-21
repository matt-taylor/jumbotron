# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ReadCurrentLinesWorkflow < CommandTower::Workflows::ApplicationWorkflow
      include PublicRead

      retry_strategy :none

      def call(**kwargs)
        deserialized = Deserializers::Public::GameIds.call(kwargs)
        return map_deserializer_failure(deserialized) unless deserialized.success?

        loaded = Services::Public::LoadGamesByIds.call(game_ids: deserialized.input.game_ids)
        return map_service_failure(loaded) unless loaded.success?

        resolved = Services::Public::ResolveCurrentLinesForGames.call(games: loaded.data[:games])
        return map_service_failure(resolved) unless resolved.success?

        mapped = Services::Public::MapPublicCurrentLines.call(current_lines: resolved.data[:current_lines])
        return map_service_failure(mapped) unless mapped.success?

        success(payload: { current_lines: mapped.data[:public_current_lines] }, http_status: :ok)
      end
    end
  end
end
