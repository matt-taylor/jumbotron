# frozen_string_literal: true

module Jumbotron
  class SandboxGamePlan < ApplicationRecord
    IMMUTABLE_ATTRIBUTES = %w[game_id home_score away_score selected_at].freeze

    belongs_to :game, inverse_of: :sandbox_game_plan

    validates :game_id, uniqueness: true
    validates :home_score, :away_score,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :selected_at, presence: true
    validate :selected_outcome_is_immutable, on: :update

    private

    def selected_outcome_is_immutable
      return unless IMMUTABLE_ATTRIBUTES.any? { |attribute| will_save_change_to_attribute?(attribute) }

      errors.add(:base, "selected sandbox outcome is immutable")
    end
  end
end
