# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_league, class: "Jumbotron::League" do
    association :sport, factory: :jumbotron_sport
    sequence(:name) { |n| "League #{n}" }
  end
end
