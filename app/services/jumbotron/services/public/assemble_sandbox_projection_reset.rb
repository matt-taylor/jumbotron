# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class AssembleSandboxProjectionReset < CommandTower::Services::ApplicationService
        validate :projection, required: true
        validate :snapshot, required: true
        validate :counts, required: true
        validate :reset_at, required: true

        def call
          context.public_reset = Jumbotron::Public::SandboxProjectionReset.new(
            projection: projection_identity,
            source_anchor_date: snapshot.source_anchor_date,
            target_anchor_date: snapshot.target_anchor_date,
            date_shift_days: snapshot.date_shift_days,
            projected_game_count: snapshot.games.count,
            added_game_count: counts.fetch(:added),
            updated_game_count: counts.fetch(:updated),
            removed_game_count: counts.fetch(:removed),
            start_week_game_count: counts.fetch(:start_week),
            naturally_locked_game_count: counts.fetch(:naturally_locked),
            reset_at: reset_at
          )
        end

        private

        def projection_identity
          Jumbotron::Public::SandboxProjection.new(
            name: projection.name,
            source: selector(projection.source_season, projection.source_anchor_phase.name),
            sandbox: selector(projection.sandbox_season, projection.source_anchor_phase.name)
          )
        end

        def selector(season, phase_name)
          Jumbotron::Public::SandboxScheduleSelector.new(
            sport: season.league.sport.name,
            league: season.league.name,
            season: season.name,
            season_phase: phase_name
          )
        end
      end
    end
  end
end
