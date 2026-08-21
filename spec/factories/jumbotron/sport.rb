# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_sport, class: "Jumbotron::Sport" do
    sequence(:name) { |n| "Sport #{n}" }
  end
end
