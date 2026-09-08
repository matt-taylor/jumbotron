# frozen_string_literal: true

module Jumbotron
  module Providers
    module Sandbox
      module Resources
        module Projection
          module_function

          def acquire(adapter:, **projection)
            unless adapter.provider.to_s == "sandbox"
              return CommandTower::Clients::ClientResult.failure(
                error: ArgumentError.new("sandbox projection requires sandbox adapter")
              )
            end

            CommandTower::Clients::ClientResult.success(output: projection)
          end
        end
      end
    end
  end
end
