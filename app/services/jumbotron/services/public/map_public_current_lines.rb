# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class MapPublicCurrentLines < CommandTower::Services::ApplicationService
        validate :current_lines, required: false

        def call
          context.public_current_lines = Array(current_lines).map do |line|
            Jumbotron::Public::CurrentLine.new(
              game_id: line.game_id,
              bookmaker_id: line.bookmaker_id,
              bookmaker_name: line.bookmaker_name,
              market: line.market,
              outcome: line.outcome,
              line_value: line.line_value,
              price_american: line.price_american,
              observed_at: line.observed_at,
              changed_at: line.changed_at
            )
          end
        end
      end
    end
  end
end
