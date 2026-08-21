# frozen_string_literal: true

module Jumbotron
  module Errors
    module Public
      class NotFoundError < CommandTower::Errors::ApplicationError
        def code
          details.is_a?(Hash) && details[:code].present? ? details[:code].to_s : "not_found"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "resource was not found"
        end
      end

      class InvalidRequestError < CommandTower::Errors::ApplicationError
        def code
          "invalid_request"
        end

        def message
          details.is_a?(Hash) && details[:message].present? ? details[:message].to_s : "invalid public request"
        end
      end
    end
  end
end
