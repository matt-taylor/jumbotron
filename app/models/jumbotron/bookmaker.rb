# frozen_string_literal: true

module Jumbotron
  class Bookmaker < ApplicationRecord
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception
    has_many :line_observations, inverse_of: :bookmaker, dependent: :restrict_with_exception

    validates :name, presence: true
    validates :observed_at, :changed_at, presence: true
  end
end
