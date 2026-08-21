# frozen_string_literal: true

module Jumbotron
  class ScheduleGroup < ApplicationRecord
    belongs_to :season, inverse_of: :schedule_groups
    belongs_to :season_phase, optional: true, inverse_of: :schedule_groups
    has_many :games, inverse_of: :schedule_group, dependent: :restrict_with_exception

    validates :kind, presence: true
    validates :name, presence: true
    validate :season_phase_belongs_to_season

    private

    def season_phase_belongs_to_season
      return if season_phase.blank? || season.blank?
      return if season_phase.season_id == season_id

      errors.add(:season_phase, "must belong to the same season")
    end
  end
end
