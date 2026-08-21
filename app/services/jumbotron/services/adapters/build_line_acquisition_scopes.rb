# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class BuildLineAcquisitionScopes < CommandTower::Services::ApplicationService
        validate :adapter, required: true
        validate :games, required: true

        def call
          seen = {}
          scopes = []
          incomplete = 0
          games_by_id = Game.where(id: Array(games).map(&:id)).includes(:provider_identities).index_by(&:id)
          Array(games).each do |game|
            scoped_game = games_by_id[game.id] || game
            scope = adapter.line_acquisition_scope_for(scoped_game)
            if scope.nil?
              incomplete += 1
              next
            end

            key = [
              scope.fetch(:endpoint),
              Synchronization::Lease.normalized_acquisition_parts(scope.fetch(:acquisition))
            ]
            next if seen[key]

            seen[key] = true
            scopes << { endpoint: scope.fetch(:endpoint), acquisition: scope.fetch(:acquisition) }
          end

          context.scopes = scopes
          context.skipped_incomplete_scope = incomplete
        end
      end
    end
  end
end
