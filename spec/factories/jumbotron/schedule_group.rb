# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_schedule_group, class: "Jumbotron::ScheduleGroup" do
    association :season, factory: :jumbotron_season
    season_phase { association :jumbotron_season_phase, season: season }
    kind { "week" }
    sequence(:number) { |n| n }
    name { "Week #{number}" }
  end
end
