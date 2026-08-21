# frozen_string_literal: true

module Jumbotron
  module Clients
    class Espn
      module Scoreboard
        class GetInput < CommandTower::Clients::EndpointInput
          attribute :sport, :string
          attribute :league, :string
          attribute :season_type
          attribute :week
          attribute :dates
        end
      end
    end
  end
end
