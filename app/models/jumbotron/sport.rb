# frozen_string_literal: true

module Jumbotron
  class Sport < ApplicationRecord
    has_many :leagues, inverse_of: :sport, dependent: :restrict_with_exception
    has_many :provider_identities, as: :target, inverse_of: :target, dependent: :restrict_with_exception

    validates :name, presence: true
  end
end
