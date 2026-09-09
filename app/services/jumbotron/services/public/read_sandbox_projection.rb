# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class ReadSandboxProjection < CommandTower::Services::ApplicationService
        validate :name, required: true

        def call
          projection = Jumbotron::SandboxProjection.includes(
            :source_anchor_phase,
            source_season: { league: :sport },
            sandbox_season: { league: :sport }
          ).find_by(name:)
          return reject if projection.nil?

          context.projection = projection
        end

        private

        def reject
          context.fail!(
            application_error: Jumbotron::Errors::Public::NotFoundError.new(
              details: { code: "sandbox_not_found", message: "sandbox projection was not found" }
            )
          )
        end
      end
    end
  end
end
