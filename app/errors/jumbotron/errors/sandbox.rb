# frozen_string_literal: true

module Jumbotron
  module Errors
    module Sandbox
      class InvalidGameError < CommandTower::Errors::ApplicationError
        def code
          "invalid_sandbox_game"
        end

        def message
          "game is not an eligible sandbox game"
        end
      end

      class OutcomeLineUnavailableError < CommandTower::Errors::ApplicationError
        def code
          "sandbox_outcome_line_unavailable"
        end

        def message
          "sandbox outcome requires current home spread and over total lines"
        end
      end

      class InvalidProgressionStateError < CommandTower::Errors::ApplicationError
        def code
          "invalid_sandbox_progression_state"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "sandbox state cannot progress"
        end
      end

      class ProjectionNotFoundError < CommandTower::Errors::ApplicationError
        def code
          "sandbox_not_found"
        end

        def message
          "sandbox projection was not found"
        end
      end

      class ProjectionConflictError < CommandTower::Errors::ApplicationError
        def code
          "sandbox_projection_conflict"
        end

        def message
          "sandbox projection conflicts with its registered source"
        end
      end

      class ProjectionRejectedError < CommandTower::Errors::ApplicationError
        def code
          details.is_a?(Hash) && details[:code].present? ? details[:code].to_s : "sandbox_projection_incomplete"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "sandbox projection was rejected"
        end
      end
    end
  end
end
