# frozen_string_literal: true

require "time"

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        class Scoreboard
          def self.call(board, observed_at:)
            events = board.respond_to?(:events) ? board.events : Array(board)
            Canonical::SyncInput.new(
              observed_at: observed_at,
              games: events.map { |event| transform_event(event) },
              teams: []
            )
          end

          def self.transform_event(event)
            competition = event.competitions&.first
            raise TransformError, "event #{event.id} missing competition" if competition.nil?

            status = competition.status || event.status
            raise TransformError, "event #{event.id} missing status" if status.nil?

            lifecycle = Lifecycle.call(status.type_name)
            season = event.season
            if season.nil? || season.year.nil? || season.type.nil?
              raise TransformError,
                    "event #{event.id} missing season"
            end

            participants = Array(competition.competitors)
            raise TransformError, "event #{event.id} requires exactly 2 competitors" unless participants.length == 2

            Canonical::GameInput.new(
              provider_identities: identities_for(event, competition),
              scheduled_at: parse_time(event.date.presence || competition.date.presence || competition.start_date),
              lifecycle: lifecycle,
              neutral_site: competition.neutral_site,
              season_year: season.year.to_i,
              season_phase_key: SeasonPhase.call(season.type),
              schedule_group: schedule_group_for(event),
              venue: transform_venue(competition.venue),
              participants: participants.map { |c| transform_participant(c, lifecycle) },
              progress: Progress.call(status, lifecycle: lifecycle)
            )
          end
          private_class_method :transform_event

          def self.schedule_group_for(event)
            number = event.week&.number
            return if number.nil?

            Canonical::ScheduleGroupInput.new(
              kind: "week",
              number: number,
              name: "Week #{number}"
            )
          end
          private_class_method :schedule_group_for

          def self.identities_for(event, competition)
            ids = []
            if event.id.present?
              ids << Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "event", id: event.id.to_s)
            end
            if competition.id.present?
              ids << Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "competition",
                                                        id: competition.id.to_s)
            end
            raise TransformError, "event/competition provider id required" if ids.empty?

            ids.uniq
          end
          private_class_method :identities_for

          def self.transform_venue(venue)
            return nil if venue.nil?
            raise TransformError, "venue id required" if venue.id.blank?
            raise TransformError, "venue name required" if venue.full_name.blank?

            Canonical::VenueInput.new(
              provider_identities: [
                Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "venue", id: venue.id.to_s)
              ],
              name: venue.full_name.to_s
            )
          end
          private_class_method :transform_venue

          def self.transform_participant(competitor, lifecycle)
            team = competitor.team
            raise TransformError, "competitor missing team" if team.nil?
            raise TransformError, "team id required" if team.id.blank?

            name = team.display_name.presence || team.name
            raise TransformError, "team name required" if name.blank?
            raise TransformError, "home_away required" if competitor.home_away.blank?

            Canonical::ParticipantInput.new(
              provider_identities: [
                Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "team", id: team.id.to_s)
              ],
              team_name: name.to_s,
              team_nickname: TeamNickname.resolve(team),
              role: competitor.home_away.to_s,
              score: coerce_score(competitor.score),
              result: coerce_result(competitor.winner, lifecycle)
            )
          end
          private_class_method :transform_participant

          def self.coerce_score(raw)
            return nil if raw.nil? || raw == ""

            Integer(raw)
          rescue ArgumentError, TypeError
            raise TransformError, "invalid score: #{raw.inspect}"
          end
          private_class_method :coerce_score

          def self.coerce_result(winner, lifecycle)
            return nil unless lifecycle == "completed"
            return nil if winner.nil?

            winner ? "win" : "loss"
          end
          private_class_method :coerce_result

          def self.parse_time(raw)
            raise TransformError, "scheduled_at missing" if raw.blank?

            Time.iso8601(raw.to_s)
          rescue ArgumentError, TypeError
            begin
              Time.zone.parse(raw.to_s) || (raise ArgumentError)
            rescue ArgumentError, TypeError
              raise TransformError, "scheduled_at unparseable: #{raw.inspect}"
            end
          end
          private_class_method :parse_time
        end
      end
    end
  end
end
