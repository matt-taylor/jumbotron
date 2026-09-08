# frozen_string_literal: true

FactoryBot.define do
  factory :jumbotron_sandbox_game_mapping, class: "Jumbotron::SandboxGameMapping" do
    association :sandbox_projection, factory: :jumbotron_sandbox_projection
    source_game do
      association(
        :jumbotron_game,
        season: sandbox_projection.source_season,
        league: sandbox_projection.source_season.league
      )
    end
    sandbox_game do
      association(
        :jumbotron_game,
        season: sandbox_projection.sandbox_season,
        league: sandbox_projection.sandbox_season.league
      )
    end
    home_spread { BigDecimal("-3.5") }
    total { BigDecimal("44.5") }
    line_fingerprint { "line-v1" }
  end
end
