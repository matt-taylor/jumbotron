# frozen_string_literal: true

module Jumbotron
  module Public # rubocop:disable Metrics/ModuleLength
    ALLOWED_INCLUDES = %i[consensus current_lines consensus_constituents].freeze

    Sport = Data.define(:id, :name)
    League = Data.define(:id, :name, :sport)
    Season = Data.define(:id, :name, :starts_on, :ends_on)
    SeasonPhase = Data.define(:id, :name)
    ScheduleGroup = Data.define(:id, :kind, :number, :name)
    ScheduleGroupEnumeration = Data.define(:groups, :completeness)
    SandboxScheduleSelector = Data.define(:sport, :league, :season, :season_phase)
    RegisterSandboxProjectionRequest = Data.define(:name, :source)
    ResetSandboxProjectionRequest = Data.define(:sandbox, :start_week, :anchor_day, :now)
    SandboxProjectionRequest = Data.define(:name)
    SandboxProjection = Data.define(:name, :source_label, :source, :sandbox)
    SandboxProjectionReset = Data.define(
      :projection,
      :source_anchor_date,
      :target_anchor_date,
      :date_shift_days,
      :projected_game_count,
      :added_game_count,
      :updated_game_count,
      :removed_game_count,
      :start_week_game_count,
      :naturally_locked_game_count,
      :reset_at
    )
    ScheduleGroupsRequest = Data.define(
      :league_id,
      :sport,
      :league,
      :season_id,
      :season,
      :season_phase,
      :kind
    )
    Team = Data.define(:id, :name, :nickname, :key, :abbreviation) do
      def initialize(id:, name:, key:, nickname: nil, abbreviation: nil)
        super(id:, name:, nickname:, key:, abbreviation:)
      end
    end
    Venue = Data.define(:id, :name, :city, :region) do
      def initialize(id:, name:, city: nil, region: nil)
        super
      end
    end
    Participant = Data.define(:role, :score, :result, :team, :record) do
      def initialize(role:, score:, result:, team:, record: nil)
        super
      end
    end
    GameSegment = Data.define(:kind, :number)
    # Clock label text. Name is canonical/public contract, not Kernel#display.
    GameClock = Data.define(:mode, :seconds, :display) # rubocop:disable Lint/DataDefineOverride
    GameProgress = Data.define(:state, :segment, :clock)
    ConsensusConstituent = Data.define(:bookmaker_id)
    CurrentLine = Data.define(
      :game_id,
      :bookmaker_id,
      :bookmaker_name,
      :market,
      :outcome,
      :line_value,
      :price_american,
      :observed_at,
      :changed_at
    )
    ConsensusLine = Data.define(
      :game_id,
      :market,
      :outcome,
      :line_value,
      :constituent_count,
      :observed_at,
      :constituents
    )
    Game = Data.define(
      :id,
      :scheduled_at,
      :lifecycle,
      :progress,
      :neutral_site,
      :observed_at,
      :changed_at,
      :venue,
      :participants,
      :consensus_lines,
      :current_lines
    )
    Schedule = Data.define(
      :league,
      :season,
      :season_phase,
      :group,
      :starts_at,
      :ends_at,
      :games
    )
    GameRequest = Data.define(:id, :includes)
    GameIdsRequest = Data.define(:game_ids)
    ScheduleRequest = Data.define(
      :league_id,
      :sport,
      :league,
      :season_id,
      :season,
      :season_phase,
      :schedule_group_id,
      :group,
      :starts_at,
      :ends_at,
      :includes
    )
  end
end
