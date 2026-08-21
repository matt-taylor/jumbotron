# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      class Schedule < CommandTower::Deserializers::ApplicationDeserializer
        def call(params)
          values = {}
          %i[
            league_id sport league season_id season season_phase schedule_group_id
            group starts_at ends_at include
          ].each do |key|
            raw = unwrap(fetch_param(params, key))
            return raw if deserializer_result?(raw)

            values[key] = raw
          end

          league_id = optional_positive_integer(values[:league_id], "league_id")
          return league_id if deserializer_result?(league_id)

          season_id = optional_positive_integer(values[:season_id], "season_id")
          return season_id if deserializer_result?(season_id)

          schedule_group_id = optional_positive_integer(values[:schedule_group_id], "schedule_group_id")
          return schedule_group_id if deserializer_result?(schedule_group_id)

          sport = optional_name(values[:sport])
          return sport if deserializer_result?(sport)

          league = optional_name(values[:league])
          return league if deserializer_result?(league)

          season = optional_name(values[:season])
          return season if deserializer_result?(season)

          season_phase = optional_name(values[:season_phase])
          return season_phase if deserializer_result?(season_phase)

          group = parse_group(values[:group])
          return group if deserializer_result?(group)

          starts_at = parse_time(values[:starts_at], "starts_at")
          return starts_at if deserializer_result?(starts_at)

          ends_at = parse_time(values[:ends_at], "ends_at")
          return ends_at if deserializer_result?(ends_at)

          includes = unwrap(Includes.parse(values[:include]))
          return includes if deserializer_result?(includes)

          request = Jumbotron::Public::ScheduleRequest.new(
            league_id: league_id,
            sport: sport,
            league: league,
            season_id: season_id,
            season: season,
            season_phase: season_phase,
            schedule_group_id: schedule_group_id,
            group: group,
            starts_at: starts_at,
            ends_at: ends_at,
            includes: includes
          )
          error = validate_modes(request)
          return error if error

          success(request)
        end

        private

        def optional_positive_integer(raw, field)
          return if raw.nil?

          unwrap(require_integer(raw, field: field, min: 1))
        end

        def optional_name(raw)
          return if raw.nil?

          unwrap(require_string(raw, field: "name"))
        end

        def parse_group(raw)
          return if raw.nil?
          return failure(errors: [{ code: "invalid_request", message: "group must be a hash" }]) unless raw.is_a?(Hash)

          hash = raw.respond_to?(:to_h) ? raw.to_h : raw
          kind_raw = hash[:kind] || hash["kind"]
          number_raw = hash[:number] || hash["number"]
          kind = unwrap(require_string(kind_raw, field: "group.kind"))
          return kind if deserializer_result?(kind)

          number = unwrap(require_integer(number_raw, field: "group.number", min: 1))
          return number if deserializer_result?(number)

          { kind: kind, number: number }
        end

        def parse_time(raw, field)
          return if raw.nil?
          return raw if raw.is_a?(Time) || raw.is_a?(ActiveSupport::TimeWithZone)

          failure(errors: [{ code: "invalid_request", message: "#{field} must be a Time" }])
        end

        def validate_modes(request)
          has_league = request.league_id.present? || (request.sport.present? && request.league.present?)
          unless has_league
            return failure(
              errors: [{ code: "invalid_request", message: "league_id or sport+league is required" }]
            )
          end

          has_group = request.schedule_group_id.present? || request.group.present?
          has_time = request.starts_at.present? && request.ends_at.present?
          if has_group && has_time
            return failure(
              errors: [{ code: "invalid_request", message: "provide group or time range, not both" }]
            )
          end
          if !has_group && !has_time
            return failure(
              errors: [{ code: "invalid_request", message: "provide group or starts_at/ends_at" }]
            )
          end
          if has_time && (request.starts_at.blank? || request.ends_at.blank?)
            return failure(
              errors: [{ code: "invalid_request", message: "starts_at and ends_at are required together" }]
            )
          end
          if has_group && request.schedule_group_id.blank?
            unless request.season_id.present? || request.season.present?
              return failure(
                errors: [{ code: "invalid_request", message: "season_id or season is required for group queries" }]
              )
            end
            if request.season_phase.blank?
              return failure(
                errors: [{ code: "invalid_request", message: "season_phase is required for group queries" }]
              )
            end
          end

          nil
        end
      end
    end
  end
end
