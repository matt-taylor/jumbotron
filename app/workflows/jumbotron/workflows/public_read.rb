# frozen_string_literal: true

module Jumbotron
  module Workflows
    module PublicRead
      def map_deserializer_failure(deserialized)
        error = Array(deserialized.errors).first
        message =
          if error.is_a?(Hash)
            error[:message].presence || error[:code].to_s
          else
            error.to_s
          end
        failure(
          errors: [{ code: "invalid_request", message: message.presence || "invalid_request" }],
          http_status: :unprocessable_entity
        )
      end

      def map_service_failure(result)
        error = Array(result.errors).first
        code = error.respond_to?(:code) ? error.code.to_s : "invalid_request"
        message = error.respond_to?(:message) ? error.message : error.to_s
        status = Public::TranslateOutcome::NOT_FOUND_CODES.include?(code) ? :not_found : :unprocessable_entity
        failure(errors: [{ code: code, message: message }], http_status: status)
      end
    end
  end
end
