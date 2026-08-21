# frozen_string_literal: true

module Jumbotron
  module Clients
    class Espn
      module Teams
        class Get < CommandTower::Clients::EndpointBase
          authentication :none
          http_method :get
          path { |input| "#{input.sport}/#{input.league}/teams" }
          input GetInput
          request_serializer ::Jumbotron::Serializers::Clients::Espn::Teams::Get
          response_deserializer ::Jumbotron::Deserializers::Clients::Espn::Teams::Get
        end
      end
    end
  end
end
