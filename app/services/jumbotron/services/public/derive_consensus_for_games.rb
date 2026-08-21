# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class DeriveConsensusForGames < CommandTower::Services::ApplicationService
        validate :current_lines, required: false

        def call
          derived = Canonical::DeriveConsensusForGames.call(current_lines: current_lines)
          unless derived.success?
            context.fail!(application_error: derived.errors.first)
            return
          end

          context.consensus_lines = Array(derived.data[:consensus_lines])
        end
      end
    end
  end
end
