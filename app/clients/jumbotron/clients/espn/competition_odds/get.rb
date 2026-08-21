# frozen_string_literal: true

module Jumbotron
  module Clients
    class Espn
      module CompetitionOdds
        class Get < CommandTower::Clients::EndpointBase
          authentication :none
          http_method :get
          path do |input|
            relative = [
              "sports", input.sport, "leagues", input.league,
              "events", input.event_id,
              "competitions", input.competition_id,
              "odds"
            ].join("/")
            CommandTower::Clients::Url.join(Jumbotron::Clients::Espn.core_base_url, relative)
          end
          input GetInput
          request_serializer ::Jumbotron::Serializers::Clients::Espn::CompetitionOdds::Get
          response_deserializer ::Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::Get
        end
      end
    end
  end
end
