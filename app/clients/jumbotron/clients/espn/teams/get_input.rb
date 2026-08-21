# frozen_string_literal: true

module Jumbotron
  module Clients
    class Espn
      module Teams
        class GetInput < CommandTower::Clients::EndpointInput
          attribute :sport, :string
          attribute :league, :string
          attribute :limit
        end
      end
    end
  end
end
