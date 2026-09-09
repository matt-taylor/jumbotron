# frozen_string_literal: true

module Jumbotron
  module Services
    module Sandbox
      class RegisterProjection < CommandTower::Services::ApplicationService
        validate :request, required: true

        def call # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          source_season, source_phase = resolve_source
          return if source_season.nil?

          existing = Jumbotron::SandboxProjection.find_by(name: request.name)
          return reuse_or_reject(existing, source_season, source_phase) if existing

          sandbox_league = ensure_sandbox_league
          return if sandbox_league.nil?

          sandbox_season = Jumbotron::Season.find_or_create_by!(league: sandbox_league, name: request.name)
          context.projection = Jumbotron::SandboxProjection.create!(
            name: request.name,
            source_season: source_season,
            source_anchor_phase: source_phase,
            sandbox_season: sandbox_season,
            adapter_id: "sandbox_nfl",
            calendar_time_zone: "America/New_York"
          )
        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
          reject("sandbox_projection_conflict", e.message)
        end

        private

        def resolve_source # rubocop:disable Metrics/AbcSize
          selector = request.source
          sport = Jumbotron::Sport.where("LOWER(name) = ?", selector.sport.downcase).first
          league = sport.leagues.where("LOWER(name) = ?", selector.league.downcase).first if sport
          season = league.seasons.where("LOWER(name) = ?", selector.season.downcase).first if league
          phase = season.season_phases.where("LOWER(name) = ?", selector.season_phase.downcase).first if season
          return [season, phase] if season && phase

          reject("source_season_not_found", "registered source season or phase was not found")
          [nil, nil]
        end

        def ensure_sandbox_league
          result = Jumbotron::Services::Adapters::EnsureLeague.call(
            adapter: Jumbotron::Adapters::Sandbox::Nfl
          )
          return result.data[:league] if result.success?

          reject("sandbox_projection_conflict", result.errors.first.to_s)
          nil
        end

        def reuse_or_reject(existing, source_season, source_phase)
          if existing.source_season_id == source_season.id &&
             existing.source_anchor_phase_id == source_phase.id
            context.projection = existing
            return
          end

          reject("sandbox_projection_conflict", "sandbox name is already registered to another source")
        end

        def reject(code, message)
          context.fail!(
            application_error: Jumbotron::Errors::Sandbox::ProjectionRejectedError.new(
              details: { code: code, message: message }
            )
          )
        end
      end
    end
  end
end
