# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class EnsureScheduleGroup < CommandTower::Services::ApplicationService
        validate :season, required: true
        validate :season_phase, required: false
        validate :schedule_group_input, required: false

        def call
          context.schedule_group = resolve_group
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end

        private

        def resolve_group
          input = schedule_group_input
          return if input.nil?

          group = ScheduleGroup.find_or_initialize_by(
            season_id: season.id,
            season_phase_id: season_phase&.id,
            kind: input.kind.to_s,
            name: input.name.to_s
          )
          group.number = input.number
          group.save!
          group
        end
      end
    end
  end
end
