# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_game_participant, class: "Jumbotron::GameParticipant" do
    association :game, factory: :jumbotron_game
    association :team, factory: :jumbotron_team
    observed_at { Time.current }
    changed_at { Time.current }
  end
end
