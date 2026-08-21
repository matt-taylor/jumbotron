# frozen_string_literal: true

module Jumbotron
  class Team < ApplicationRecord
    has_many :game_participants, inverse_of: :team, dependent: :restrict_with_exception
    has_many :games, through: :game_participants
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception

    validates :name, presence: true
  end
end
