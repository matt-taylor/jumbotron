# frozen_string_literal: true

module Jumbotron
  class League < ApplicationRecord
    belongs_to :sport, inverse_of: :leagues
    has_many :seasons, inverse_of: :league, dependent: :restrict_with_exception
    has_many :games, inverse_of: :league, dependent: :restrict_with_exception
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception

    validates :name, presence: true
  end
end
