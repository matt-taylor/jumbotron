# frozen_string_literal: true

module Jumbotron
  module Adapters
    module LineAcquisition
      def line_acquisition_scope_for(_game)
        nil
      end

      def acquire_line_odds(_acquisition)
        raise ConfigurationError, "#{name} must implement acquire_line_odds"
      end

      def translate_line_odds(*)
        raise ConfigurationError, "#{name} must implement translate_line_odds"
      end
    end
  end
end
