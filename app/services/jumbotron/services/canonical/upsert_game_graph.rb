# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class UpsertGameGraph < CommandTower::Services::ApplicationService
        validate :game_input, required: true
        validate :league, required: true
        validate :observed_at, required: true
        validate :change_set, required: true

        def call
          season = resolve(EnsureSeason.call(league: league, year: game_input.season_year), :season)
          return if season.nil?

          phase = resolve(
            EnsureSeasonPhase.call(season: season, phase_key: game_input.season_phase_key),
            :season_phase
          )
          return if phase.nil?

          group = resolve_group(season, phase)
          return if context.failure?

          venue = resolve(
            UpsertVenue.call(
              venue_input: game_input.venue,
              observed_at: observed_at,
              change_set: change_set
            ),
            :venue,
            allow_nil: true
          )
          return if context.failure?

          game = upsert_game(season, phase, group, venue)
          return if game.nil?
          return unless attach_identities?(game)
          return unless upsert_participants?(game)

          context.game = game
        end

        private

        def resolve_group(season, phase)
          resolve(
            EnsureScheduleGroup.call(
              season: season,
              season_phase: phase,
              schedule_group_input: game_input.schedule_group
            ),
            :schedule_group,
            allow_nil: true
          )
        end

        def upsert_game(season, phase, group, venue)
          resolve(
            UpsertGame.call(
              game_input: game_input,
              league: league,
              season: season,
              season_phase: phase,
              schedule_group: group,
              venue: venue,
              observed_at: observed_at,
              change_set: change_set
            ),
            :game
          )
        end

        def attach_identities?(game)
          result = AttachProviderIdentities.call(target: game, refs: game_input.provider_identities)
          return true if result.success?

          fail_from(result)
          false
        end

        def upsert_participants?(game)
          game_input.participants.each do |participant_input|
            result = UpsertGameParticipant.call(
              game: game,
              participant_input: participant_input,
              observed_at: observed_at,
              change_set: change_set,
              preserve_existing_team: sandbox_game_input?
            )
            unless result.success?
              fail_from(result)
              return false
            end
          end
          true
        end

        def sandbox_game_input?
          game_input.provider_identities.any? { |identity| identity.provider == "sandbox" }
        end

        def resolve(result, key, allow_nil: false)
          unless result.success?
            fail_from(result)
            return
          end

          value = result.data[key]
          return value if allow_nil || !value.nil?

          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: "#{key} was not resolved" }
            )
          )
          nil
        end

        def fail_from(result)
          context.fail!(application_error: Array(result.errors).first)
        end
      end
    end
  end
end
