# frozen_string_literal: true

module Jumbotron
  module Serializers
    module Clients
      module Espn
        module CompetitionOdds
          class Get
            def self.call(_input)
              CommandTower::Clients::SerializedRequest.build(query: {})
            end
          end
        end
      end
    end
  end
end
