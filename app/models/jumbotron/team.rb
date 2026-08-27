# frozen_string_literal: true

module Jumbotron
  class Team < ApplicationRecord
    has_many :game_participants, inverse_of: :team, dependent: :restrict_with_exception
    has_many :games, through: :game_participants
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception

    validates :name, presence: true
    validates :key, presence: true, uniqueness: true
    validate :key_format_must_be_semantic

    private

    def key_format_must_be_semantic
      return if key.blank?
      return if Jumbotron::TeamKey.valid_format?(key)

      errors.add(:key, "must be a lowercase kebab-case semantic key")
    end
  end
end
