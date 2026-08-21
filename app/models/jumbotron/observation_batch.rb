# frozen_string_literal: true

module Jumbotron
  class ObservationBatch < ApplicationRecord
    has_many :historical_changes,
             inverse_of: :observation_batch,
             dependent: :restrict_with_exception
    has_many :line_observations,
             inverse_of: :observation_batch,
             dependent: :restrict_with_exception

    validates :provider, :adapter_scope, :observed_at, presence: true
  end
end
