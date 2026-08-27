# frozen_string_literal: true

require "rails"
require "command_tower"
require "jumbotron/version"
require "jumbotron/team_key"
require "jumbotron/engine"
require "jumbotron/client"

module Jumbotron
  def self.client
    Client.new
  end
end
