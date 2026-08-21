# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class LoadGamesByIds < CommandTower::Services::ApplicationService
        validate :game_ids, required: false

        def call
          ids = Array(game_ids)
          games = Game.includes(ReadGame::ASSOCIATIONS).where(id: ids).to_a
          by_id = games.index_by(&:id)
          context.games = ids.filter_map { |id| by_id[id] }
        end
      end
    end
  end
end
