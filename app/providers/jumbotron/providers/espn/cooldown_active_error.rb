# frozen_string_literal: true

module Jumbotron
  module Providers
    module Espn
      class CooldownActiveError < StandardError
        def initialize(msg = "ESPN provider cooldown is active")
          super
        end
      end
    end
  end
end
