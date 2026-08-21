# frozen_string_literal: true

module Jumbotron
  class Season < ApplicationRecord
    belongs_to :league, inverse_of: :seasons
    has_many :season_phases, inverse_of: :season, dependent: :restrict_with_exception
    has_many :schedule_groups, inverse_of: :season, dependent: :restrict_with_exception
    has_many :games, inverse_of: :season, dependent: :restrict_with_exception
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception

    validates :name, presence: true
  end
end
