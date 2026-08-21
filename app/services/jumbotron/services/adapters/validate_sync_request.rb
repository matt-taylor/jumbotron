# frozen_string_literal: true

module Jumbotron
  module Services
    module Adapters
      class ValidateSyncRequest < CommandTower::Services::ApplicationService
        validate :adapter, required: true
        validate :endpoint, required: true
        validate :league_id, required: true

        def call
          unless adapter.respond_to?(:registered?) && adapter.respond_to?(:operation) &&
                 adapter.respond_to?(:endpoints)
            context.fail!(application_error: Jumbotron::Errors::Adapters::InvalidAdapterError.new)
            return
          end

          unless adapter.registered?
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::NotRegisteredError.new(
                details: { adapter: adapter.to_s }
              )
            )
            return
          end

          unless adapter.endpoints.key?(endpoint.to_sym)
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::UnknownEndpointError.new(
                details: { endpoint: endpoint }
              )
            )
            return
          end

          league = Jumbotron::League.find_by(id: league_id)
          if league.nil?
            context.fail!(
              application_error: Jumbotron::Errors::Adapters::LeagueNotFoundError.new(
                details: { league_id: league_id }
              )
            )
            return
          end

          context.league = league
        end
      end
    end
  end
end
