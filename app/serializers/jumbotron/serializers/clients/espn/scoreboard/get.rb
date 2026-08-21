# frozen_string_literal: true

module Jumbotron
  module Serializers
    module Clients
      module Espn
        module Scoreboard
          class Get
            def self.call(input)
              query = {}
              query["seasontype"] = input.season_type unless input.season_type.nil?
              query["week"] = input.week unless input.week.nil?
              query["dates"] = input.dates unless input.dates.nil?

              CommandTower::Clients::SerializedRequest.build(query: query)
            end
          end
        end
      end
    end
  end
end
