# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class ReadSchedule < CommandTower::Services::ApplicationService
        validate :request, required: true

        def call
          league = resolve_league
          return if context.failure?

          if league.nil?
            not_found("league_not_found", "league was not found")
            return
          end

          season = resolve_season(league)
          return if context.failure?

          phase = resolve_phase(season)
          return if context.failure?

          group = resolve_group(season, phase)
          return if context.failure?

          games = load_games(league, season, phase, group)
          context.league = league
          context.season = season
          context.season_phase = phase
          context.schedule_group = group
          context.games = games
        end

        private

        def resolve_league
          return League.includes(:sport).find_by(id: request.league_id) if request.league_id.present?

          sport = Sport.where("LOWER(name) = ?", request.sport.to_s.downcase).first
          return if sport.nil?

          sport.leagues.where("LOWER(name) = ?", request.league.to_s.downcase).first
        end

        def resolve_season(league)
          return if request.season_id.blank? && request.season.blank?

          season =
            if request.season_id.present?
              Season.find_by(id: request.season_id, league_id: league.id)
            else
              league.seasons.where("LOWER(name) = ?", request.season.to_s.downcase).first
            end
          not_found("season_not_found", "season was not found") if season.nil?
          season
        end

        def resolve_phase(season)
          return if request.season_phase.blank?

          if season.nil?
            not_found("season_not_found", "season was not found")
            return
          end

          phase = season.season_phases.where("LOWER(name) = ?", request.season_phase.to_s.downcase).first
          not_found("season_phase_not_found", "season phase was not found") if phase.nil?
          phase
        end

        def resolve_group(season, phase)
          return if request.schedule_group_id.blank? && request.group.blank?

          group =
            if request.schedule_group_id.present?
              ScheduleGroup.find_by(id: request.schedule_group_id)
            else
              if season.nil? || phase.nil?
                not_found("schedule_group_not_found", "schedule group was not found")
                return
              end
              ScheduleGroup.find_by(
                season_id: season.id,
                season_phase_id: phase.id,
                kind: request.group[:kind],
                number: request.group[:number]
              )
            end
          not_found("schedule_group_not_found", "schedule group was not found") if group.nil?
          group
        end

        def load_games(league, season, phase, group)
          relation = Game.includes(ReadGame::ASSOCIATIONS).where(league_id: league.id)
          relation = relation.where(season_id: season.id) if season
          relation = relation.where(season_phase_id: phase.id) if phase
          if group
            relation = relation.where(schedule_group_id: group.id)
          elsif request.starts_at && request.ends_at
            relation = relation.where(scheduled_at: request.starts_at..request.ends_at)
          end
          relation.order(:scheduled_at, :id).to_a
        end

        def not_found(code, message)
          context.fail!(
            application_error: Jumbotron::Errors::Public::NotFoundError.new(
              details: { code: code, message: message }
            )
          )
        end
      end
    end
  end
end
