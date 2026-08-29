# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class UpsertGameParticipant < CommandTower::Services::ApplicationService
        validate :game, required: true
        validate :participant_input, required: true
        validate :observed_at, required: true
        validate :change_set, required: true

        def call
          team_result = UpsertTeam.call(
            team_input: Jumbotron::Canonical::TeamInput.new(
              provider_identities: participant_input.provider_identities,
              name: participant_input.team_name,
              nickname: participant_input.team_nickname,
              abbreviation: participant_input.team_abbreviation
            ),
            observed_at: observed_at,
            change_set: change_set
          )
          unless team_result.success?
            context.fail!(application_error: team_result.errors.first)
            return
          end

          team = team_result.data[:team]
          participant = game.game_participants.lock.find_by(team_id: team.id)
          context.game_participant = resolve_participant(participant, team)
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def resolve_participant(participant, team)
          if participant
            update_existing!(participant)
          else
            create_new!(team)
          end
        end

        def create_new!(team)
          attrs = {
            team: team,
            role: participant_input.role,
            score: participant_input.score,
            result: participant_input.result,
            observed_at: observed_at,
            changed_at: observed_at
          }.merge(initial_record_attrs)
          gp = game.game_participants.create!(attrs)
          change_set.record(subject: gp, attribute: "role", previous: nil, new_value: gp.role)
          change_set.record(subject: gp, attribute: "score", previous: nil, new_value: gp.score)
          record_create_history!(gp)
          gp
        end

        def update_existing!(participant)
          material = false
          {
            role: participant_input.role,
            score: participant_input.score,
            result: participant_input.result
          }.each do |key, value|
            current = participant.public_send(key)
            next if current == value

            change_set.record(
              subject: participant,
              attribute: key.to_s,
              previous: current,
              new_value: value
            )
            participant.public_send("#{key}=", value)
            material = true
          end
          material |= apply_record_snapshots!(participant)
          participant.observed_at = observed_at
          participant.changed_at = observed_at if material
          participant.save!
          participant
        end

        def initial_record_attrs
          summary = participant_input.record_summary
          return {} if summary.blank?

          attrs = {
            record_summary_current: summary,
            record_observed_at: observed_at
          }
          if game.lifecycle == "completed"
            attrs[:record_summary_post_game] = summary
          elsif game.lifecycle != "cancelled"
            attrs[:record_summary_entering] = summary
          end
          attrs
        end

        def record_create_history!(participant)
          %i[
            record_summary_entering
            record_summary_current
            record_summary_post_game
          ].each do |attr|
            value = participant.public_send(attr)
            next if value.blank?

            change_set.record(subject: participant, attribute: attr.to_s, previous: nil, new_value: value)
          end
        end

        def apply_record_snapshots!(participant)
          summary = participant_input.record_summary
          return false if summary.blank?

          material = false
          if participant.record_summary_current != summary
            change_set.record(
              subject: participant,
              attribute: "record_summary_current",
              previous: participant.record_summary_current,
              new_value: summary
            )
            participant.record_summary_current = summary
            material = true
          end
          participant.record_observed_at = observed_at

          if game.lifecycle == "completed"
            material |= apply_post_game_record!(participant, summary)
          elsif game.lifecycle != "cancelled"
            material |= assign_entering_record!(participant, summary)
          end
          material
        end

        def assign_entering_record!(participant, summary) # rubocop:disable Naming/PredicateMethod
          return false if participant.record_summary_entering == summary

          change_set.record(
            subject: participant,
            attribute: "record_summary_entering",
            previous: participant.record_summary_entering,
            new_value: summary
          )
          participant.record_summary_entering = summary
          true
        end

        # Authoritative post-game only: never invent W–L; if total still equals
        # entering on a completed observation, leave post_game nil (Strategy B).
        def apply_post_game_record!(participant, summary) # rubocop:disable Naming/PredicateMethod
          entering = participant.record_summary_entering
          return false if entering.present? && summary == entering
          return false if participant.record_summary_post_game == summary

          change_set.record(
            subject: participant,
            attribute: "record_summary_post_game",
            previous: participant.record_summary_post_game,
            new_value: summary
          )
          participant.record_summary_post_game = summary
          true
        end
      end
    end
  end
end
