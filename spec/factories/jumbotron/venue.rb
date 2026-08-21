# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_venue, class: "Jumbotron::Venue" do
    sequence(:name) { |n| "Venue #{n}" }
    observed_at { Time.current }
    changed_at { Time.current }
  end
end
