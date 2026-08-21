# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      # Persists the Game row only. Callers supply resolved season/phase/venue.
      class UpsertGame < CommandTower::Services::ApplicationService
        MATERIAL_ATTRS = %i[
          season_id
          season_phase_id
          schedule_group_id
          scheduled_at
          lifecycle
          venue_id
          neutral_site
          progress_state
          progress_segment_kind
          progress_segment_number
          progress_clock_mode
        ].freeze

        SILENT_ATTRS = %i[
          progress_clock_seconds
          progress_clock_display
        ].freeze

        validate :game_input, required: true
        validate :league, required: true
        validate :season, required: true
        validate :season_phase, required: true
        validate :schedule_group, required: false
        validate :venue, required: false
        validate :observed_at, required: true
        validate :change_set, required: true

        def call
          game = find_game
          context.game = resolve_game(game)
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def resolve_game(game)
          if game
            update_existing!(Game.lock.find(game.id))
          else
            create_new!
          end
        end

        def find_game
          game_input.provider_identities.each do |ref|
            identity = ProviderIdentity.find_by(
              provider: ref.provider,
              object_namespace: ref.namespace,
              provider_id: ref.id
            )
            return identity.target if identity&.target.is_a?(Game)
          end
          nil
        end

        def create_new!
          game = Game.create!(create_attrs)
          record_create_history!(game)
          game
        end

        def create_attrs
          {
            league: league,
            season: season,
            season_phase: season_phase,
            schedule_group: schedule_group,
            venue: venue,
            scheduled_at: game_input.scheduled_at,
            lifecycle: game_input.lifecycle,
            neutral_site: game_input.neutral_site.nil? ? false : game_input.neutral_site,
            observed_at: observed_at,
            changed_at: observed_at
          }.merge(progress_column_values)
        end

        def record_create_history!(game)
          change_set.record(subject: game, attribute: "lifecycle", previous: nil, new_value: game.lifecycle)
          change_set.record(
            subject: game,
            attribute: "scheduled_at",
            previous: nil,
            new_value: game.scheduled_at&.iso8601
          )
          MATERIAL_ATTRS.grep(/\Aprogress_/).each do |key|
            value = game.public_send(key)
            next if value.nil?

            change_set.record(subject: game, attribute: key.to_s, previous: nil, new_value: serialize(value))
          end
        end

        def update_existing!(game)
          attrs = {
            season_id: season.id,
            season_phase_id: season_phase.id,
            schedule_group_id: schedule_group&.id,
            scheduled_at: game_input.scheduled_at,
            lifecycle: game_input.lifecycle
          }
          attrs[:venue_id] = venue&.id unless game_input.venue.nil?
          attrs[:neutral_site] = game_input.neutral_site unless game_input.neutral_site.nil?
          attrs.merge!(progress_column_values)

          material = apply_material_attrs!(game, attrs)
          apply_silent_attrs!(game, attrs)

          game.observed_at = observed_at
          game.changed_at = observed_at if material
          game.save!
          game
        end

        def apply_material_attrs!(game, attrs)
          material = false
          attrs.slice(*MATERIAL_ATTRS).each do |key, value|
            current = game.public_send(key)
            next if serialize(current) == serialize(value)

            change_set.record(
              subject: game,
              attribute: key.to_s,
              previous: serialize(current),
              new_value: serialize(value)
            )
            game.public_send("#{key}=", value)
            material = true
          end
          material
        end

        def apply_silent_attrs!(game, attrs)
          attrs.slice(*SILENT_ATTRS).each do |key, value|
            game.public_send("#{key}=", value)
          end
        end

        def progress_column_values
          progress = game_input.progress
          if progress.nil?
            {
              progress_state: nil,
              progress_segment_kind: nil,
              progress_segment_number: nil,
              progress_clock_mode: nil,
              progress_clock_seconds: nil,
              progress_clock_display: nil
            }
          else
            clock = progress.clock
            {
              progress_state: progress.state,
              progress_segment_kind: progress.segment.kind,
              progress_segment_number: progress.segment.number,
              progress_clock_mode: clock&.mode,
              progress_clock_seconds: clock&.seconds,
              progress_clock_display: clock&.display
            }
          end
        end

        def serialize(value)
          case value
          when Time, ActiveSupport::TimeWithZone
            value.iso8601
          else
            value
          end
        end
      end
    end
  end
end
