# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class AssembleSandboxProjection < CommandTower::Services::ApplicationService
        validate :projection, required: true

        def call
          context.public_projection = Jumbotron::Public::SandboxProjection.new(
            name: projection.name,
            source: selector(projection.source_season, projection.source_anchor_phase.name),
            sandbox: selector(projection.sandbox_season, projection.source_anchor_phase.name)
          )
        end

        private

        def selector(season, phase_name)
          Jumbotron::Public::SandboxScheduleSelector.new(
            sport: season.league.sport.name,
            league: season.league.name,
            season: season.name,
            season_phase: phase_name
          )
        end
      end
    end
  end
end
