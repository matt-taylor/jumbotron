# frozen_string_literal: true

module Jumbotron
  module SandboxProjectionData
    Team = Data.define(:provider_id, :name, :nickname, :abbreviation)
    Game = Data.define(
      :source_game_id,
      :event_id,
      :competition_id,
      :scheduled_at,
      :season,
      :season_phase,
      :week_number,
      :week_name,
      :neutral_site,
      :home,
      :away,
      :home_spread,
      :total,
      :line_fingerprint,
      :line_source
    )
    Snapshot = Data.define(
      :games,
      :source_anchor_date,
      :target_anchor_date,
      :date_shift_days,
      :fingerprint,
      :start_week
    )
  end
end
