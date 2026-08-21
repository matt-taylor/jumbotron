# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_line_observation, class: "Jumbotron::LineObservation" do
    association :game, factory: :jumbotron_game
    association :bookmaker, factory: :jumbotron_bookmaker
    association :observation_batch, factory: :jumbotron_observation_batch
    market { "spread" }
    outcome { "home" }
    source { "observed" }
    line_value { BigDecimal("-3.5") }
    price_american { -110 }
    observed_at { Time.current }
    changed_at { Time.current }
  end
end
