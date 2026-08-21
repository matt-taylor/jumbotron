# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class AssemblePublicSchedule < CommandTower::Services::ApplicationService
        validate :request, required: true
        validate :league, required: true
        validate :public_games, required: false
        validate :season, required: false
        validate :season_phase, required: false
        validate :schedule_group, required: false

        def call
          context.schedule = Jumbotron::Public::Schedule.new(
            league: build_league(league),
            season: build_season(season),
            season_phase: build_phase(season_phase),
            group: build_group(schedule_group),
            starts_at: request.starts_at,
            ends_at: request.ends_at,
            games: Array(public_games)
          )
        end

        private

        def build_league(record)
          sport = Jumbotron::Public::Sport.new(id: record.sport.id, name: record.sport.name)
          Jumbotron::Public::League.new(id: record.id, name: record.name, sport: sport)
        end

        def build_season(record)
          return if record.nil?

          Jumbotron::Public::Season.new(
            id: record.id,
            name: record.name,
            starts_on: record.starts_on,
            ends_on: record.ends_on
          )
        end

        def build_phase(record)
          return if record.nil?

          Jumbotron::Public::SeasonPhase.new(id: record.id, name: record.name)
        end

        def build_group(record)
          return if record.nil?

          Jumbotron::Public::ScheduleGroup.new(
            id: record.id,
            kind: record.kind,
            number: record.number,
            name: record.name
          )
        end
      end
    end
  end
end
