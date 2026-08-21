# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class EnsureSeason < CommandTower::Services::ApplicationService
        validate :league, required: true
        validate :year, required: true

        def call
          context.season = Season.find_or_create_by!(league_id: league.id, name: year.to_s)
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
