# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ReadConsensusWorkflow < CommandTower::Workflows::ApplicationWorkflow
      include PublicRead

      retry_strategy :none

      def call(**kwargs)
        deserialized = Deserializers::Public::GameIds.call(kwargs)
        return map_deserializer_failure(deserialized) unless deserialized.success?

        loaded = Services::Public::LoadGamesByIds.call(game_ids: deserialized.input.game_ids)
        return map_service_failure(loaded) unless loaded.success?

        games = loaded.data[:games]
        resolved = Services::Public::ResolveCurrentLinesForGames.call(games: games)
        return map_service_failure(resolved) unless resolved.success?

        derived = Services::Public::DeriveConsensusForGames.call(
          current_lines: resolved.data[:current_lines]
        )
        return map_service_failure(derived) unless derived.success?

        mapped = Services::Public::MapPublicConsensusLines.call(
          consensus_lines: derived.data[:consensus_lines],
          current_lines: resolved.data[:current_lines],
          include_constituents: false
        )
        return map_service_failure(mapped) unless mapped.success?

        success(payload: { consensus_lines: mapped.data[:public_consensus_lines] }, http_status: :ok)
      end
    end
  end
end
