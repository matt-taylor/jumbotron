# frozen_string_literal: true

module Jumbotron
  class Error < StandardError
    attr_reader :code, :details

    def initialize(message = nil, code: "internal_error", details: {})
      @code = code.to_s
      @details = details || {}
      super(message)
    end
  end
end
