# frozen_string_literal: true

require "json"

module Jumbotron
  module Clients
    class Espn < CommandTower::Clients::ClientBase
      DEFAULT_BASE_URL = "https://site.api.espn.com/apis/site/v2/sports"
      DEFAULT_CORE_BASE_URL = "https://sports.core.api.espn.com/v2"

      def self.core_base_url
        ENV.fetch("JUMBOTRON_ESPN_CORE_BASE_URL", DEFAULT_CORE_BASE_URL)
      end

      def decode_response(response)
        CommandTower::Clients::DecodedResponse.new(
          payload: parse_json(response.body),
          provider_metadata: {}
        )
      end

      protected

      def base_url
        ENV.fetch("JUMBOTRON_ESPN_SITE_BASE_URL", DEFAULT_BASE_URL)
      end

      def default_headers
        { "Accept" => "application/json" }
      end

      private

      def parse_json(body)
        JSON.parse(body.to_s)
      rescue JSON::ParserError => e
        raise CommandTower::Clients::Errors::DeserializationError.new(
          message: "ESPN response body is not valid JSON: #{e.message}",
          details: { path: "", expected: "JSON object", actual: "invalid_json", rule: "type", messages: [e.message] }
        )
      end
    end
  end
end
