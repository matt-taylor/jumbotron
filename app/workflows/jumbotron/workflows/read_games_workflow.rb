# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ReadGamesWorkflow < CommandTower::Workflows::ApplicationWorkflow
      include PublicRead

      retry_strategy :none

      def call(**kwargs)
        deserialized = Deserializers::Public::Games.call(kwargs)
        return map_deserializer_failure(deserialized) unless deserialized.success?

        request = deserialized.input
        loaded = Services::Public::LoadGamesByIds.call(game_ids: request.game_ids)
        return map_service_failure(loaded) unless loaded.success?

        games = Array(loaded.data[:games])
        included = Services::Public::LoadIncludedLines.call(games: games, includes: request.includes)
        return map_service_failure(included) unless included.success?

        public_games = games.map do |game|
          assembled = Services::Public::AssemblePublicGame.call(
            game: game,
            includes: request.includes,
            current_lines: included.data[:current_lines],
            consensus_lines: included.data[:consensus_lines]
          )
          return map_service_failure(assembled) unless assembled.success?

          assembled.data[:public_game]
        end

        success(payload: { games: public_games }, http_status: :ok)
      end
    end
  end
end
