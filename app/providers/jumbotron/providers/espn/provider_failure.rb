# frozen_string_literal: true

module Jumbotron
  module Providers
    module Espn
      module ProviderFailure
        module_function

        def availability_failure?(error)
          return false unless error.is_a?(CommandTower::Clients::Errors::UpstreamError)

          return true if server_error_status?(error)
          return true if transport_cause?(error.cause)

          false
        end

        def server_error_status?(error)
          status = error.details.is_a?(Hash) ? error.details[:status] : nil
          status.is_a?(Integer) && status >= 500
        end

        def transport_cause?(cause)
          return false if cause.nil?
          return true if cause.is_a?(CommandTower::Clients::Transport::Error)
          return true if defined?(Faraday) && cause.is_a?(Faraday::Error)
          return true if cause.is_a?(Timeout::Error)
          return true if cause.is_a?(SocketError)
          return true if cause.is_a?(Errno::ECONNREFUSED)
          return true if cause.is_a?(Errno::ECONNRESET)
          return true if cause.is_a?(Errno::ETIMEDOUT)
          return true if cause.is_a?(Net::OpenTimeout)
          return true if cause.is_a?(Net::ReadTimeout)

          false
        end
      end
    end
  end
end
