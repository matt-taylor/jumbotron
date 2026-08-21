# frozen_string_literal: true

module Jumbotron
  module Clients
    class Espn
      module CompetitionOdds
        class GetInput < CommandTower::Clients::EndpointInput
          attribute :sport, :string
          attribute :league, :string
          attribute :event_id, :string
          attribute :competition_id, :string
        end
      end
    end
  end
end
