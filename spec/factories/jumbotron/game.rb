# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_game, class: "Jumbotron::Game" do
    league { association :jumbotron_league }
    season { association :jumbotron_season, league: league }
    observed_at { Time.current }
    changed_at { Time.current }
  end
end
