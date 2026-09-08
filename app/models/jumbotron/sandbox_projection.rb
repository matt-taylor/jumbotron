# frozen_string_literal: true

module Jumbotron
  class SandboxProjection < ApplicationRecord
    belongs_to :source_season, class_name: "Jumbotron::Season", inverse_of: :source_sandbox_projections
    belongs_to :source_anchor_phase, class_name: "Jumbotron::SeasonPhase"
    belongs_to :sandbox_season, class_name: "Jumbotron::Season", inverse_of: :sandbox_projection
    has_many :sandbox_game_mappings, inverse_of: :sandbox_projection, dependent: :restrict_with_exception

    validates :name, presence: true, uniqueness: true, format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
    validates :adapter_id, inclusion: { in: %w[sandbox_nfl] }
    validates :calendar_time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:tzinfo).map(&:name) }
    validate :anchor_phase_belongs_to_source
    validate :source_and_sandbox_are_distinct

    private

    def anchor_phase_belongs_to_source
      return if source_anchor_phase.nil? || source_anchor_phase.season_id == source_season_id

      errors.add(:source_anchor_phase, "must belong to source season")
    end

    def source_and_sandbox_are_distinct
      return unless source_season_id == sandbox_season_id

      errors.add(:sandbox_season, "must differ from source season")
    end
  end
end
