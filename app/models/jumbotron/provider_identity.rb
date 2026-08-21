# frozen_string_literal: true

module Jumbotron
  class ProviderIdentity < ApplicationRecord
    TARGET_TYPES = [
      "Jumbotron::Sport",
      "Jumbotron::League",
      "Jumbotron::Season",
      "Jumbotron::SeasonPhase",
      "Jumbotron::Team",
      "Jumbotron::Venue",
      "Jumbotron::Game",
      "Jumbotron::Bookmaker"
    ].freeze

    belongs_to :target, polymorphic: true, inverse_of: :provider_identities

    before_validation :normalize_provider

    validates :provider, presence: true
    validates :object_namespace, presence: true
    validates :provider_id, presence: true
    validates :target_type, inclusion: { in: TARGET_TYPES }
    validates :provider_id, uniqueness: { scope: %i[provider object_namespace] }

    private

    def normalize_provider
      self.provider = provider&.strip&.downcase
    end
  end
end
