# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_sandbox_game_plan, class: "Jumbotron::SandboxGamePlan" do
    association :game, factory: :jumbotron_game
    home_score { 24 }
    away_score { 20 }
    selected_at { Time.current }
  end
end
