# frozen_string_literal: true

module Jumbotron
  module Serializers
    module Clients
      module Espn
        module Teams
          class Get
            def self.call(input)
              query = {}
              query["limit"] = input.limit unless input.limit.nil?

              CommandTower::Clients::SerializedRequest.build(query: query)
            end
          end
        end
      end
    end
  end
end
