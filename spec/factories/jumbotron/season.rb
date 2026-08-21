# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_season, class: "Jumbotron::Season" do
    association :league, factory: :jumbotron_league
    sequence(:name) { |n| "Season #{n}" }
  end
end
