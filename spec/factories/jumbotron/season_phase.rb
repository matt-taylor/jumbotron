# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_season_phase, class: "Jumbotron::SeasonPhase" do
    association :season, factory: :jumbotron_season
    sequence(:name) { |n| "Phase #{n}" }
  end
end
