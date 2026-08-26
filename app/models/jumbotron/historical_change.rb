# frozen_string_literal: true

module Jumbotron
  class HistoricalChange < ApplicationRecord
    belongs_to :observation_batch, inverse_of: :historical_changes

    # Force JSON attribute types so writes are JSON.generate'd on every adapter.
    # MariaDB stores t.json as LONGTEXT + json_valid CHECK; without :json, AR
    # persists Ruby #inspect and discovery/evidence writes fail CheckViolation.
    attribute :previous_value, :json
    attribute :new_value, :json

    validates :subject_type, :subject_id, :attribute_name, :observed_at, :provider, presence: true
  end
end
