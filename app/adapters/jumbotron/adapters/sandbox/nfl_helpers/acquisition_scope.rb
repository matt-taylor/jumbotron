# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module AcquisitionScope
          module_function

          def call(game) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
            group = game.schedule_group
            event = identity_for(game, "event")
            competition = identity_for(game, "competition")
            home = participant_payload_for(game, "home")
            away = participant_payload_for(game, "away")
            return unless valid?(group, event, home, away)

            {
              endpoint: :scoreboard,
              acquisition: {
                game_id: game.id,
                event_id: event.provider_id,
                competition_id: competition&.provider_id,
                scheduled_at: game.scheduled_at.iso8601,
                season_year: season_identity(game.season.name),
                season_phase_key: game.season_phase.name,
                week_number: group.number,
                home: home,
                away: away
              }
            }
          rescue ArgumentError, NoMethodError, TypeError
            nil
          end

          def season_identity(value)
            Integer(value, exception: false) || value.to_s
          end
          private_class_method :season_identity

          def identity_for(game, namespace)
            game.provider_identities.find do |identity|
              identity.provider == "sandbox" && identity.object_namespace == namespace
            end
          end
          private_class_method :identity_for

          def participant_payload_for(game, role) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
            participant = game.game_participants.find { |row| row.role == role }
            return if participant.nil?

            identity = participant.team.provider_identities.find do |candidate|
              candidate.provider == "espn" && candidate.object_namespace == "team"
            end
            return if identity.nil?

            {
              provider_id: identity.provider_id,
              name: participant.team.name,
              nickname: participant.team.nickname,
              abbreviation: participant.team.abbreviation
            }
          end
          private_class_method :participant_payload_for

          def valid?(group, event, home, away)
            group&.kind == "week" && group.number.present? && event.present? && home.present? && away.present?
          end
          private_class_method :valid?
        end
      end
    end
  end
end
