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
              name: participant_input.team_name
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
          gp = game.game_participants.create!(
            team: team,
            role: participant_input.role,
            score: participant_input.score,
            result: participant_input.result,
            observed_at: observed_at,
            changed_at: observed_at
          )
          change_set.record(subject: gp, attribute: "role", previous: nil, new_value: gp.role)
          change_set.record(subject: gp, attribute: "score", previous: nil, new_value: gp.score)
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
          participant.observed_at = observed_at
          participant.changed_at = observed_at if material
          participant.save!
          participant
        end
      end
    end
  end
end
