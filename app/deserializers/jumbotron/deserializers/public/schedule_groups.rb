# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Public
      class ScheduleGroups < CommandTower::Deserializers::ApplicationDeserializer
        def call(params)
          values = {}
          %i[league_id sport league season_id season season_phase kind].each do |key|
            raw = unwrap(fetch_param(params, key))
            return raw if deserializer_result?(raw)

            values[key] = raw
          end

          league_id = optional_positive_integer(values[:league_id], "league_id")
          return league_id if deserializer_result?(league_id)

          season_id = optional_positive_integer(values[:season_id], "season_id")
          return season_id if deserializer_result?(season_id)

          sport = optional_name(values[:sport])
          return sport if deserializer_result?(sport)

          league = optional_name(values[:league])
          return league if deserializer_result?(league)

          season = optional_name(values[:season])
          return season if deserializer_result?(season)

          season_phase = optional_name(values[:season_phase])
          return season_phase if deserializer_result?(season_phase)

          kind = optional_name(values[:kind])
          return kind if deserializer_result?(kind)

          request = Jumbotron::Public::ScheduleGroupsRequest.new(
            league_id: league_id,
            sport: sport,
            league: league,
            season_id: season_id,
            season: season,
            season_phase: season_phase,
            kind: kind
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

        def validate_modes(request)
          has_league = request.league_id.present? || (request.sport.present? && request.league.present?)
          unless has_league
            return failure(
              errors: [{ code: "invalid_request", message: "league_id or sport+league is required" }]
            )
          end

          unless request.season_id.present? || request.season.present?
            return failure(
              errors: [{ code: "invalid_request", message: "season_id or season is required" }]
            )
          end

          if request.season_phase.blank?
            return failure(
              errors: [{ code: "invalid_request", message: "season_phase is required" }]
            )
          end

          nil
        end
      end
    end
  end
end
