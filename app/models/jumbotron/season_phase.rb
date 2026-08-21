# frozen_string_literal: true

module Jumbotron
  class SeasonPhase < ApplicationRecord
    belongs_to :season, inverse_of: :season_phases
    has_many :schedule_groups, inverse_of: :season_phase, dependent: :restrict_with_exception
    has_many :games, inverse_of: :season_phase, dependent: :restrict_with_exception
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception

    validates :name, presence: true
  end
end
