# frozen_string_literal: true

module Jumbotron
  class Game < ApplicationRecord
    LIFECYCLES = %w[
      scheduled
      in_progress
      completed
      postponed
      cancelled
      suspended
    ].freeze

    PROGRESS_STATES = %w[active intermission].freeze
    PROGRESS_CLOCK_MODES = %w[remaining elapsed].freeze
    PROGRESS_CORE_ATTRIBUTES = %i[
      progress_state
      progress_segment_kind
      progress_segment_number
    ].freeze
    PROGRESS_CLOCK_ATTRIBUTES = %i[
      progress_clock_mode
      progress_clock_seconds
      progress_clock_display
    ].freeze
    PROGRESS_ATTRIBUTES = (PROGRESS_CORE_ATTRIBUTES + PROGRESS_CLOCK_ATTRIBUTES).freeze

    belongs_to :league, inverse_of: :games
    belongs_to :season, inverse_of: :games
    belongs_to :season_phase, optional: true, inverse_of: :games
    belongs_to :schedule_group, optional: true, inverse_of: :games
    belongs_to :venue, optional: true, inverse_of: :games
    has_many :game_participants, inverse_of: :game, dependent: :restrict_with_exception
    has_many :teams, through: :game_participants
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception
    has_many :line_observations, inverse_of: :game, dependent: :restrict_with_exception
    has_one :sandbox_game_plan, inverse_of: :game, dependent: :restrict_with_exception
    has_many :source_sandbox_game_mappings,
             class_name: "Jumbotron::SandboxGameMapping",
             foreign_key: :source_game_id,
             inverse_of: :source_game,
             dependent: :restrict_with_exception
    has_one :sandbox_game_mapping,
            class_name: "Jumbotron::SandboxGameMapping",
            foreign_key: :sandbox_game_id,
            inverse_of: :sandbox_game,
            dependent: :restrict_with_exception

    attribute :lifecycle, :string, default: "scheduled"
    attribute :neutral_site, :boolean, default: false

    validates :lifecycle, inclusion: { in: LIFECYCLES }
    validates :progress_state, inclusion: { in: PROGRESS_STATES, allow_nil: true }
    validates :progress_clock_mode, inclusion: { in: PROGRESS_CLOCK_MODES, allow_nil: true }
    validate :season_belongs_to_league
    validate :season_phase_belongs_to_season
    validate :schedule_group_belongs_to_season
    validate :progress_is_all_nil_or_core_complete
    validate :intermission_has_no_clock

    private

    def season_belongs_to_league
      return if season.blank? || league.blank?
      return if season.league_id == league_id

      errors.add(:season, "must belong to the same league")
    end

    def season_phase_belongs_to_season
      return if season_phase.blank? || season.blank?
      return if season_phase.season_id == season_id

      errors.add(:season_phase, "must belong to the same season")
    end

    def schedule_group_belongs_to_season
      return if schedule_group.blank? || season.blank?
      return if schedule_group.season_id == season_id

      errors.add(:schedule_group, "must belong to the same season")
    end

    def progress_is_all_nil_or_core_complete
      values = PROGRESS_ATTRIBUTES.map { |attribute| public_send(attribute) }
      return if values.all?(&:nil?)
      return if progress_core_complete?

      errors.add(:progress_state, "must include state, segment kind, and segment number together")
    end

    def progress_core_complete?
      progress_state.present? && progress_segment_kind.present? && !progress_segment_number.nil?
    end

    def intermission_has_no_clock
      return unless progress_state == "intermission"
      return if PROGRESS_CLOCK_ATTRIBUTES.all? { |attribute| public_send(attribute).nil? }

      errors.add(:progress_clock_mode, "must be blank during intermission")
    end
  end
end
