# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      # Lists observed ScheduleGroups for a resolved SeasonPhase.
      # Completeness is always :incomplete until a dedicated authoritative catalog exists.
      class ReadScheduleGroups < CommandTower::Services::ApplicationService
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
          return if season.nil?

          phase = resolve_phase(season)
          return if context.failure?
          return if phase.nil?

          records = load_groups(season, phase)
          groups = records.map { |record| build_group(record) }

          context.schedule_groups = Jumbotron::Public::ScheduleGroupEnumeration.new(
            groups: groups,
            completeness: :incomplete
          )
        end

        private

        def resolve_league
          return League.includes(:sport).find_by(id: request.league_id) if request.league_id.present?

          sport = Sport.where("LOWER(name) = ?", request.sport.to_s.downcase).first
          return if sport.nil?

          sport.leagues.where("LOWER(name) = ?", request.league.to_s.downcase).first
        end

        def resolve_season(league)
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
          phase = season.season_phases.where("LOWER(name) = ?", request.season_phase.to_s.downcase).first
          not_found("season_phase_not_found", "season phase was not found") if phase.nil?
          phase
        end

        def load_groups(season, phase)
          relation = ScheduleGroup.where(season_id: season.id, season_phase_id: phase.id)
          relation = relation.where(kind: request.kind) if request.kind.present?
          relation.order(Arel.sql("number IS NULL, number ASC, name ASC, id ASC")).to_a
        end

        def build_group(record)
          Jumbotron::Public::ScheduleGroup.new(
            id: record.id,
            kind: record.kind,
            number: record.number,
            name: record.name
          )
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
