# frozen_string_literal: true

module Jumbotron
  class Season < ApplicationRecord
    belongs_to :league, inverse_of: :seasons
    has_many :season_phases, inverse_of: :season, dependent: :restrict_with_exception
    has_many :schedule_groups, inverse_of: :season, dependent: :restrict_with_exception
    has_many :games, inverse_of: :season, dependent: :restrict_with_exception
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception
    has_many :source_sandbox_projections,
             class_name: "Jumbotron::SandboxProjection",
             foreign_key: :source_season_id,
             inverse_of: :source_season,
             dependent: :restrict_with_exception
    has_one :sandbox_projection,
            class_name: "Jumbotron::SandboxProjection",
            foreign_key: :sandbox_season_id,
            inverse_of: :sandbox_season,
            dependent: :restrict_with_exception

    validates :name, presence: true
  end
end
