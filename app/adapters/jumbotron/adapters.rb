# frozen_string_literal: true

module Jumbotron
  module Adapters
    class RegistrationError < StandardError; end
    class TransformError < StandardError; end
    class ConfigurationError < StandardError; end
    class UnknownPolicyError < StandardError; end
    class UnknownDiscoveryError < StandardError; end
  end
end
