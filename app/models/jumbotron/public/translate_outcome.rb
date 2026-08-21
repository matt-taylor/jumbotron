# frozen_string_literal: true

module Jumbotron
  module Public
    module TranslateOutcome
      NOT_FOUND_CODES = %w[
        not_found
        game_not_found
        league_not_found
        season_not_found
        season_phase_not_found
        schedule_group_not_found
      ].freeze

      module_function

      def call(result, payload_key:)
        unless result.is_a?(CommandTower::Workflows::WorkflowResult)
          raise Jumbotron::Error, "unexpected internal result"
        end

        return result.payload.fetch(payload_key) if result.success?

        raise public_error_for(result)
      end

      def public_error_for(result)
        code, message = error_code_and_message(result)
        klass = exception_class_for(code)
        klass.new(message)
      end
      module_function :public_error_for

      def error_code_and_message(result)
        error = Array(result.errors).first
        case error
        when CommandTower::Errors::ApplicationError
          [error.code.to_s, error.message]
        when Hash
          [(error[:code] || error["code"]).to_s, (error[:message] || error["message"]).to_s]
        else
          ["internal_error", error.to_s]
        end
      end
      module_function :error_code_and_message

      def exception_class_for(code)
        return Jumbotron::NotFoundError if NOT_FOUND_CODES.include?(code)
        return Jumbotron::InvalidRequestError if code == "invalid_request"
        return Jumbotron::UnsupportedCapabilityError if code == "unsupported"

        Jumbotron::Error
      end
      module_function :exception_class_for
    end
  end
end
