# frozen_string_literal: true

module Jumbotron
  class HistoricalChange < ApplicationRecord
    belongs_to :observation_batch, inverse_of: :historical_changes

    validates :subject_type, :subject_id, :attribute_name, :observed_at, :provider, presence: true
  end
end
