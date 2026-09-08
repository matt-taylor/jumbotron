# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_sandbox_projection, class: "Jumbotron::SandboxProjection" do
    sequence(:name) { |number| "sandbox-#{number}" }
    association :source_season, factory: :jumbotron_season
    source_anchor_phase do
      association :jumbotron_season_phase, season: source_season, name: "regular_season"
    end
    sandbox_season do
      sport = association(:jumbotron_sport, name: "football")
      league = association(:jumbotron_league, sport: sport, name: "nfl-sandbox")
      association(:jumbotron_season, league: league, name: name)
    end
    adapter_id { "sandbox_nfl" }
    calendar_time_zone { "America/New_York" }
  end
end
