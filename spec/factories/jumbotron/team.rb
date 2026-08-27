# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_team, class: "Jumbotron::Team" do
    sequence(:name) { |n| "Team #{n}" }
    observed_at { Time.current }
    changed_at { Time.current }

    after(:build) do |team|
      next if team.key.present?

      team.key = Jumbotron::TeamKey.normalize(team.name)
    end
  end
end
