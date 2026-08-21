# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_observation_batch, class: "Jumbotron::ObservationBatch" do
    provider { "espn" }
    adapter_scope { "espn_nfl" }
    observed_at { Time.current }
    metadata { {} }
  end
end
