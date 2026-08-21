# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class ReadGame < CommandTower::Services::ApplicationService
        ASSOCIATIONS = [
          :venue,
          :season_phase,
          :schedule_group,
          { league: :sport, season: :league, game_participants: :team }
        ].freeze

        validate :game_id, required: true

        def call
          game = Game.includes(ASSOCIATIONS).find_by(id: game_id)
          if game.nil?
            context.fail!(
              application_error: Jumbotron::Errors::Public::NotFoundError.new(
                details: { code: "game_not_found", message: "game was not found" }
              )
            )
            return
          end

          context.game = game
        end
      end
    end
  end
end
