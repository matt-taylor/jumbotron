# frozen_string_literal: true

module Jumbotron
  class LineObservation < ApplicationRecord
    MARKETS = %w[spread total moneyline].freeze
    OUTCOMES = %w[home away over under draw].freeze
    SOURCES = %w[observed provider_open provider_close].freeze

    belongs_to :game, inverse_of: :line_observations
    belongs_to :bookmaker, inverse_of: :line_observations
    belongs_to :observation_batch, inverse_of: :line_observations

    validates :market, inclusion: { in: MARKETS }
    validates :outcome, inclusion: { in: OUTCOMES }
    validates :source, inclusion: { in: SOURCES }
    validates :observed_at, :changed_at, presence: true
  end
end
