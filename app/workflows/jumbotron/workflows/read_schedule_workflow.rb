# frozen_string_literal: true

module Jumbotron
  module Workflows
    class ReadScheduleWorkflow < CommandTower::Workflows::ApplicationWorkflow
      include PublicRead

      retry_strategy :none

      def call(**kwargs)
        deserialized = Deserializers::Public::Schedule.call(kwargs)
        return map_deserializer_failure(deserialized) unless deserialized.success?

        request = deserialized.input
        read = Services::Public::ReadSchedule.call(request: request)
        return map_service_failure(read) unless read.success?

        games = Array(read.data[:games])
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

        schedule = Services::Public::AssemblePublicSchedule.call(
          request: request,
          league: read.data[:league],
          season: read.data[:season],
          season_phase: read.data[:season_phase],
          schedule_group: read.data[:schedule_group],
          public_games: public_games
        )
        return map_service_failure(schedule) unless schedule.success?

        success(payload: { schedule: schedule.data[:schedule] }, http_status: :ok)
      end
    end
  end
end
