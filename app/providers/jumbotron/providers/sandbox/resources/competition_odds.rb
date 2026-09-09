# frozen_string_literal: true

module Jumbotron
  module Providers
    module Sandbox
      module Resources
        class CompetitionOdds
          def self.acquire(adapter:, **query)
            return invalid_adapter unless adapter.provider == "sandbox"

            CommandTower::Clients::ClientResult.success(output: query.symbolize_keys)
          end

          def self.invalid_adapter
            CommandTower::Clients::ClientResult.failure(
              error: ArgumentError.new("sandbox provider requires a sandbox adapter")
            )
          end
          private_class_method :invalid_adapter
        end
      end
    end
  end
end
