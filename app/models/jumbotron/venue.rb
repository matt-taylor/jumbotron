# frozen_string_literal: true

module Jumbotron
  class Venue < ApplicationRecord
    has_many :games, inverse_of: :venue, dependent: :restrict_with_exception
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception

    validates :name, presence: true
  end
end
