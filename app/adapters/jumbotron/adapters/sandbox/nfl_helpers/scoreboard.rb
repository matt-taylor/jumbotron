# frozen_string_literal: true

require "time"

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        class Scoreboard
          def self.call(payload, observed_at:)
            data = payload.symbolize_keys
            resolved = resolve_observation(data.fetch(:game_id), observed_at)
            Canonical::SyncInput.new(
              observed_at: observed_at,
              games: [game_input(data, resolved)],
              teams: []
            )
          rescue ArgumentError, KeyError, TypeError => e
            raise TransformError, "invalid sandbox scoreboard observation: #{e.message}"
          end

          def self.resolve_observation(game_id, observed_at)
            resolved = Jumbotron::Services::Sandbox::ResolveGameObservation.call(
              game_id: game_id,
              observed_at: observed_at
            )
            return resolved.data if resolved.success?

            error = Array(resolved.errors).first
            raise TransformError, error.respond_to?(:message) ? error.message : "sandbox observation failed"
          end
          private_class_method :resolve_observation

          def self.game_input(data, resolved)
            event_id = data.fetch(:event_id).to_s
            competition_id = data[:competition_id].presence || event_id
            Canonical::GameInput.new(**game_attributes(data, event_id, competition_id, resolved))
          end
          private_class_method :game_input

          def self.game_attributes(data, event_id, competition_id, resolved) # rubocop:disable Metrics/MethodLength
            observation = resolved.fetch(:observation)
            {
              provider_identities: game_identities(event_id, competition_id),
              scheduled_at: resolved.fetch(:scheduled_at),
              lifecycle: observation.lifecycle,
              neutral_site: false,
              season_year: season_identity(data.fetch(:season_year)),
              season_phase_key: data.fetch(:season_phase_key).to_s,
              schedule_group: schedule_group(data.fetch(:week_number)),
              venue: nil,
              participants: %i[home away].map do |role|
                participant(data.fetch(role), role, observation)
              end,
              progress: observation.progress
            }
          end
          private_class_method :game_attributes

          def self.season_identity(value)
            Integer(value, exception: false) || value.to_s
          end
          private_class_method :season_identity

          def self.game_identities(event_id, competition_id)
            [
              Canonical::ProviderIdentityRef.new(provider: "sandbox", namespace: "event", id: event_id),
              Canonical::ProviderIdentityRef.new(
                provider: "sandbox",
                namespace: "competition",
                id: competition_id.to_s
              )
            ].uniq
          end
          private_class_method :game_identities

          def self.schedule_group(number)
            week = Integer(number)
            Canonical::ScheduleGroupInput.new(kind: "week", number: week, name: "Week #{week}")
          end
          private_class_method :schedule_group

          def self.participant(raw, role, observation)
            data = raw.symbolize_keys
            Canonical::ParticipantInput.new(**participant_attributes(data, role, observation))
          end
          private_class_method :participant

          def self.participant_attributes(data, role, observation)
            {
              provider_identities: [team_identity(data.fetch(:provider_id))],
              team_name: data.fetch(:name).to_s,
              team_nickname: data[:nickname].presence,
              team_abbreviation: data[:abbreviation].presence,
              role: role.to_s,
              score: observation.public_send("#{role}_score"),
              result: observation.public_send("#{role}_result"),
              record_summary: nil
            }
          end
          private_class_method :participant_attributes

          def self.team_identity(provider_id)
            Canonical::ProviderIdentityRef.new(
              provider: "espn",
              namespace: "team",
              id: provider_id.to_s
            )
          end
          private_class_method :team_identity
        end
      end
    end
  end
end
