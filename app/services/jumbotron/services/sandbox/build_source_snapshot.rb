# frozen_string_literal: true

require "digest"
require "json"

# This service validates and snapshots the complete source projection atomically.
# rubocop:disable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength
module Jumbotron
  module Services
    module Sandbox
      class BuildSourceSnapshot < CommandTower::Services::ApplicationService
        validate :projection, required: true
        validate :start_week, required: true
        validate :anchor_day, required: true
        validate :now, required: true

        def call
          source_games = load_source_games
          return if source_games.nil?

          calendar = resolve_calendar(source_games)
          return if calendar.nil?

          raw_games = source_games.map { |game| raw_game(game) }
          return if context.failure?

          fingerprint = fingerprint_for(raw_games, calendar)
          projected_games = raw_games.map { |raw| projected_game(raw, calendar, fingerprint) }
          return if context.failure?

          context.snapshot = Jumbotron::SandboxProjectionData::Snapshot.new(
            games: projected_games,
            source_anchor_date: calendar.fetch(:source_anchor_date),
            target_anchor_date: calendar.fetch(:target_anchor_date),
            date_shift_days: calendar.fetch(:date_shift_days),
            fingerprint: fingerprint,
            start_week: start_week
          )
        end

        private

        def load_source_games
          games = projection.source_season.games.includes(
            :schedule_group,
            :season_phase,
            game_participants: { team: :provider_identities }
          ).order(:scheduled_at, :id).to_a
          return games if games.present? && games.all? { |game| complete_game?(game) }

          reject("sandbox_projection_incomplete", "source season contains incomplete game structure")
          nil
        end

        def complete_game?(game)
          game.scheduled_at.present? &&
            game.schedule_group&.kind == "week" &&
            game.schedule_group.number.present? &&
            game.season_phase.present? &&
            %w[home away].all? { |role| participant(game, role).present? }
        end

        def resolve_calendar(games)
          group = anchor_groups.one? ? anchor_groups.first : nil
          return reject_calendar("source_week_not_found", "start week is missing or ambiguous") if group.nil?

          group_games = games.select { |game| game.schedule_group_id == group.id }
          return reject_calendar("source_week_not_found", "start week has no games") if group_games.empty?
          return reject_calendar("sandbox_period_overlap", "source week windows overlap") unless non_overlapping?(games)

          zone = ActiveSupport::TimeZone[projection.calendar_time_zone]
          dates = group_games.map { |game| game.scheduled_at.in_time_zone(zone).to_date }
          first_date = dates.min
          last_date = dates.max
          span = (last_date - first_date).to_i + 1
          return reject_calendar("anchor_day_out_of_range", "anchor day exceeds source week span") if anchor_day > span

          source_anchor = first_date + (anchor_day - 1)
          target_anchor = now.in_time_zone(zone).to_date
          {
            zone: zone,
            source_anchor_date: source_anchor,
            target_anchor_date: target_anchor,
            date_shift_days: (target_anchor - source_anchor).to_i
          }
        end

        def anchor_groups
          projection.source_anchor_phase.schedule_groups.where(
            kind: "week",
            number: start_week
          ).to_a
        end

        def non_overlapping?(games)
          windows = games.group_by(&:schedule_group_id).values.map do |members|
            times = members.map(&:scheduled_at)
            times.minmax
          end.sort_by(&:first)
          windows.each_cons(2).all? { |left, right| left.last < right.first }
        end

        def raw_game(game)
          source_spread, source_total = source_consensus(game)
          {
            game: game,
            source_spread: source_spread,
            source_total: source_total,
            home: team_data(participant(game, "home").team),
            away: team_data(participant(game, "away").team)
          }
        rescue ArgumentError => e
          reject("sandbox_projection_incomplete", e.message)
          nil
        end

        def source_consensus(game)
          result = Jumbotron::Services::Canonical::DeriveConsensusLine.call(game: game)
          return [nil, nil] unless result.success?

          lines = Array(result.data[:consensus_lines])
          spread = lines.find { |line| line.market == "spread" && line.outcome == "home" }
          total = lines.find { |line| line.market == "total" && line.outcome == "over" }
          [spread&.line_value, total&.line_value]
        end

        def participant(game, role)
          game.game_participants.find { |row| row.role == role }
        end

        def team_data(team)
          identity = team.provider_identities.find do |candidate|
            candidate.provider == "espn" && candidate.object_namespace == "team"
          end
          raise ArgumentError, "source team is missing ESPN identity" if identity.nil?

          Jumbotron::SandboxProjectionData::Team.new(
            provider_id: identity.provider_id,
            name: team.name,
            nickname: team.nickname,
            abbreviation: team.abbreviation
          )
        end

        def fingerprint_for(raw_games, calendar)
          facts = raw_games.compact.map do |raw|
            game = raw.fetch(:game)
            [
              game.id,
              game.scheduled_at.iso8601,
              game.season_phase.name,
              game.schedule_group.number,
              raw[:source_spread]&.to_s,
              raw[:source_total]&.to_s
            ]
          end
          Digest::SHA256.hexdigest(
            JSON.generate(
              version: 1,
              projection: projection.name,
              start_week: start_week,
              anchor_day: anchor_day,
              now: now.iso8601,
              shift: calendar.fetch(:date_shift_days),
              games: facts
            )
          )
        end

        def projected_game(raw, calendar, fingerprint)
          game = raw.fetch(:game)
          line = Jumbotron::Services::Sandbox::SelectLineBasis.call(
            source_game_id: game.id,
            reset_fingerprint: fingerprint,
            source_spread: raw[:source_spread],
            source_total: raw[:source_total]
          )
          unless line.success?
            reject("sandbox_projection_incomplete", "sandbox line basis could not be selected")
            return
          end

          Jumbotron::SandboxProjectionData::Game.new(
            source_game_id: game.id,
            event_id: "#{projection.name}:source-game:#{game.id}",
            competition_id: "#{projection.name}:source-competition:#{game.id}",
            scheduled_at: shift_time(game.scheduled_at, calendar),
            season: projection.sandbox_season.name,
            season_phase: game.season_phase.name,
            week_number: game.schedule_group.number,
            week_name: game.schedule_group.name,
            neutral_site: game.neutral_site,
            home: raw.fetch(:home),
            away: raw.fetch(:away),
            home_spread: line.data[:home_spread],
            total: line.data[:total],
            line_fingerprint: line.data[:line_fingerprint],
            line_source: line.data[:line_source]
          )
        end

        def shift_time(time, calendar)
          time.in_time_zone(calendar.fetch(:zone))
              .advance(days: calendar.fetch(:date_shift_days))
              .utc
        end

        def reject_calendar(code, message)
          reject(code, message)
          nil
        end

        def reject(code, message)
          context.fail!(
            application_error: Jumbotron::Errors::Sandbox::ProjectionRejectedError.new(
              details: { code: code, message: message }
            )
          )
        end
      end
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/ClassLength, Metrics/CyclomaticComplexity, Metrics/MethodLength
