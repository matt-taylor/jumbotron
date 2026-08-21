# frozen_string_literal: true

module Jumbotron
  module Clients
    class Espn
      module Scoreboard
        class Get < CommandTower::Clients::EndpointBase
          authentication :none
          http_method :get
          path { |input| "#{input.sport}/#{input.league}/scoreboard" }
          input GetInput
          request_serializer ::Jumbotron::Serializers::Clients::Espn::Scoreboard::Get
          response_deserializer ::Jumbotron::Deserializers::Clients::Espn::Scoreboard::Get
        end
      end
    end
  end
end
