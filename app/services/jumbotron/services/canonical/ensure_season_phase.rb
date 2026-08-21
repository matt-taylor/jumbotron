# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class EnsureSeasonPhase < CommandTower::Services::ApplicationService
        validate :season, required: true
        validate :phase_key, required: true

        def call
          context.season_phase = SeasonPhase.find_or_create_by!(season_id: season.id, name: phase_key.to_s)
        rescue ActiveRecord::RecordInvalid => e
          context.fail!(
            application_error: Jumbotron::Errors::Canonical::MutationFailedError.new(
              details: { message: e.message }
            )
          )
        end
      end
    end
  end
end
