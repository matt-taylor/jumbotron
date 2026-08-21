# frozen_string_literal: true

module Jumbotron
  class GameParticipant < ApplicationRecord
    belongs_to :game, inverse_of: :game_participants
    belongs_to :team, inverse_of: :game_participants

    validates :team_id, uniqueness: { scope: :game_id }
  end
end
