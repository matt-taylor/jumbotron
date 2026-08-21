# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_team, class: "Jumbotron::Team" do
    sequence(:name) { |n| "Team #{n}" }
    observed_at { Time.current }
    changed_at { Time.current }
  end
end
