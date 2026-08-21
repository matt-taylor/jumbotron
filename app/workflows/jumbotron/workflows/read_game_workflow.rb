# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ReadGameWorkflow < CommandTower::Workflows::ApplicationWorkflow
      include PublicRead

      retry_strategy :none

      def call(**kwargs)
        deserialized = Deserializers::Public::Game.call(kwargs)
        return map_deserializer_failure(deserialized) unless deserialized.success?

        request = deserialized.input
        read = Services::Public::ReadGame.call(game_id: request.id)
        return map_service_failure(read) unless read.success?

        game = read.data[:game]
        included = Services::Public::LoadIncludedLines.call(games: [game], includes: request.includes)
        return map_service_failure(included) unless included.success?

        assembled = Services::Public::AssemblePublicGame.call(
          game: game,
          includes: request.includes,
          current_lines: included.data[:current_lines],
          consensus_lines: included.data[:consensus_lines]
        )
        return map_service_failure(assembled) unless assembled.success?

        success(payload: { game: assembled.data[:public_game] }, http_status: :ok)
      end
    end
  end
end
