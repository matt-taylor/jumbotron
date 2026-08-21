# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_bookmaker, class: "Jumbotron::Bookmaker" do
    sequence(:name) { |n| "Bookmaker #{n}" }
    observed_at { Time.current }
    changed_at { Time.current }
  end
end
