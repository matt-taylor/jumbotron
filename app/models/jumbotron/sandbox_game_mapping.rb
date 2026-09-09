# frozen_string_literal: true

module Jumbotron
  class SandboxGameMapping < ApplicationRecord
    belongs_to :sandbox_projection, inverse_of: :sandbox_game_mappings
    belongs_to :source_game, class_name: "Jumbotron::Game", inverse_of: :source_sandbox_game_mappings
    belongs_to :sandbox_game, class_name: "Jumbotron::Game", inverse_of: :sandbox_game_mapping

    validates :source_game_id, uniqueness: { scope: :sandbox_projection_id }
    validates :sandbox_game_id, uniqueness: true
    validates :home_spread, :total, numericality: true
    validates :line_fingerprint, presence: true
    validate :games_are_in_expected_worlds

    private

    def games_are_in_expected_worlds
      return if source_game.nil? || sandbox_game.nil?
      return if source_game.league.name != "nfl-sandbox" && sandbox_game.league.name == "nfl-sandbox"

      errors.add(:base, "mapping requires live source and sandbox target games")
    end
  end
end
