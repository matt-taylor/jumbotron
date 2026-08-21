# frozen_string_literal: true

module Jumbotron
  module SpecSupport
    module EspnScoreboardOverlay
      def espn_scoreboard_with_status(status_file)
        root = Jumbotron::Engine.root.join("spec/fixtures/espn/nfl")
        payload = JSON.parse(root.join("scoreboard_2025_w1.json").read)
        payload["events"].first["competitions"].first["status"] =
          JSON.parse(root.join("progress", status_file).read)
        payload.to_json
      end
    end
  end
end
