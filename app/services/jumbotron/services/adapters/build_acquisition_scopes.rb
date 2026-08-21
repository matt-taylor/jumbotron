# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class BuildAcquisitionScopes < CommandTower::Services::ApplicationService
        validate :adapter, required: true
        validate :games, required: true

        def call
          seen = {}
          scopes = []
          incomplete = 0
          Array(games).each do |game|
            scope = adapter.acquisition_scope_for(game)
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
