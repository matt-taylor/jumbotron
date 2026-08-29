# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class UpsertTeam < CommandTower::Services::ApplicationService
        validate :team_input, required: true
        validate :observed_at, required: true
        validate :change_set, required: true

        def call
          ref = team_input.provider_identities.first
          identity = ProviderIdentity.find_by(
            provider: ref.provider,
            object_namespace: ref.namespace,
            provider_id: ref.id
          )

          team = resolve_team(identity)

          attach = AttachProviderIdentities.call(target: team, refs: team_input.provider_identities)
          unless attach.success?
            context.fail!(application_error: attach.errors.first)
            return
          end

          context.team = team
        rescue ActiveRecord::RecordNotUnique
          context.team = recover_after_race!
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def resolve_team(identity)
          if identity&.target.is_a?(Team)
            update_existing!(identity.target_id)
          else
            create_new!
          end
        end

        def update_existing!(team_id)
          team = Team.lock.find(team_id)
          if team.name != team_input.name
            change_set.record(
              subject: team,
              attribute: "name",
              previous: team.name,
              new_value: team_input.name
            )
            team.name = team_input.name
            team.changed_at = observed_at
          end
          apply_nickname!(team)
          apply_abbreviation!(team)
          # key is immutable after assignment — never regenerate from name or provider id
          team.observed_at = observed_at
          team.save!
          team
        end

        def create_new!
          team = Team.create!(
            name: team_input.name,
            nickname: team_input.nickname,
            abbreviation: team_input.abbreviation,
            key: allocate_key!(team_input.name),
            observed_at: observed_at,
            changed_at: observed_at
          )
          change_set.record(subject: team, attribute: "name", previous: nil, new_value: team.name)
          change_set.record(subject: team, attribute: "key", previous: nil, new_value: team.key)
          if team.nickname.present?
            change_set.record(
              subject: team,
              attribute: "nickname",
              previous: nil,
              new_value: team.nickname
            )
          end
          if team.abbreviation.present?
            change_set.record(
              subject: team,
              attribute: "abbreviation",
              previous: nil,
              new_value: team.abbreviation
            )
          end
          team
        end

        def apply_nickname!(team)
          return if team_input.nickname.nil?
          return if team.nickname == team_input.nickname

          change_set.record(
            subject: team,
            attribute: "nickname",
            previous: team.nickname,
            new_value: team_input.nickname
          )
          team.nickname = team_input.nickname
          team.changed_at = observed_at
        end

        def apply_abbreviation!(team)
          return if team_input.abbreviation.nil?
          return if team.abbreviation == team_input.abbreviation

          change_set.record(
            subject: team,
            attribute: "abbreviation",
            previous: team.abbreviation,
            new_value: team_input.abbreviation
          )
          team.abbreviation = team_input.abbreviation
          team.changed_at = observed_at
        end

        def allocate_key!(name)
          base = Jumbotron::TeamKey.normalize(name)
          return base unless Team.exists?(key: base)

          suffix = 2
          loop do
            candidate = "#{base}-#{suffix}"
            return candidate unless Team.exists?(key: candidate)

            suffix += 1
          end
        end

        def recover_after_race!
          ref = team_input.provider_identities.first
          identity = ProviderIdentity.find_by!(
            provider: ref.provider,
            object_namespace: ref.namespace,
            provider_id: ref.id
          )
          team = Team.lock.find(identity.target_id)
          team.observed_at = observed_at
          team.save!
          team
        end
      end
    end
  end
end
