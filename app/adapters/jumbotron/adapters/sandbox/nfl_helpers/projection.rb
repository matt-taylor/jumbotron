# frozen_string_literal: true

require "time"

module Jumbotron
  module Adapters
    module Sandbox
      module NflHelpers
        module Projection
          module_function

          def call(payload, observed_at:)
            data = payload.symbolize_keys
            Canonical::SyncInput.new(
              observed_at: observed_at,
              games: [game_input(data)],
              teams: []
            )
          rescue ArgumentError, KeyError, TypeError => e
            raise TransformError, "invalid sandbox projection: #{e.message}"
          end

          def game_input(data) # rubocop:disable Metrics/MethodLength
            Canonical::GameInput.new(
              provider_identities: game_identities(data),
              scheduled_at: Time.iso8601(data.fetch(:scheduled_at).to_s),
              lifecycle: "scheduled",
              neutral_site: data.fetch(:neutral_site, false),
              season_year: data.fetch(:season),
              season_phase_key: data.fetch(:season_phase),
              schedule_group: schedule_group(data),
              venue: nil,
              participants: %i[home away].map { |role| participant(data.fetch(role), role) },
              progress: nil
            )
          end
          private_class_method :game_input

          def game_identities(data)
            event_id = data.fetch(:event_id).to_s
            competition_id = data.fetch(:competition_id, event_id).to_s
            [
              Canonical::ProviderIdentityRef.new(provider: "sandbox", namespace: "event", id: event_id),
              Canonical::ProviderIdentityRef.new(
                provider: "sandbox",
                namespace: "competition",
                id: competition_id
              )
            ].uniq
          end
          private_class_method :game_identities

          def schedule_group(data)
            number = Integer(data.fetch(:week_number))
            Canonical::ScheduleGroupInput.new(
              kind: "week",
              number: number,
              name: data.fetch(:week_name).to_s
            )
          end
          private_class_method :schedule_group

          def participant(raw, role) # rubocop:disable Metrics/MethodLength
            data = raw.symbolize_keys
            Canonical::ParticipantInput.new(
              provider_identities: [
                Canonical::ProviderIdentityRef.new(
                  provider: "espn",
                  namespace: "team",
                  id: data.fetch(:provider_id).to_s
                )
              ],
              team_name: data.fetch(:name).to_s,
              team_nickname: data[:nickname].presence,
              team_abbreviation: data[:abbreviation].presence,
              role: role.to_s,
              score: nil,
              result: nil,
              record_summary: nil
            )
          end
          private_class_method :participant
        end
      end
    end
  end
end
