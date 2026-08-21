# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module Scoreboard
          class Get
            class CalendarPhase < CommandTower::Deserializers::Clients::Result
              field :season_type, type: Support.types.integer, required: true
              field :weeks, type: Support.types.array(Support.types.integer), required: true
            end

            class Result < CommandTower::Deserializers::Clients::Result
              field :events, type: Support.types.array(Event::Result), required: true
              field :season_calendar, type: Support.types.array(CalendarPhase), nullable: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "scoreboard")
              events_raw = Support.payload.fetch(payload, "events")

              if events_raw.equal?(Support.missing)
                raise CommandTower::Clients::Errors::DeserializationError.new(
                  message: "events is required",
                  details: {
                    path: "events",
                    expected: "Array",
                    actual: "missing",
                    rule: "required",
                    messages: ["events is required"]
                  }
                )
              end

              unless events_raw.is_a?(Array)
                raise CommandTower::Clients::Errors::DeserializationError.new(
                  message: "events must be an Array",
                  details: {
                    path: "events",
                    expected: "Array",
                    actual: events_raw.class.name,
                    rule: "type",
                    messages: ["events must be an Array"]
                  }
                )
              end

              events = events_raw.each_with_index.map do |item, index|
                Event.call(item)
              rescue CommandTower::Clients::Errors::DeserializationError => e
                raise CommandTower::Deserializers::Clients::Errors.prefix(e, "events[#{index}]")
              end

              Result.build!(events: events, season_calendar: parse_season_calendar(payload))
            end

            def self.parse_season_calendar(payload)
              leagues = payload["leagues"]
              return [] unless leagues.is_a?(Array) && leagues.first.is_a?(Hash)

              calendar = leagues.first["calendar"]
              return [] unless calendar.is_a?(Array)

              calendar.filter_map do |entry|
                next unless entry.is_a?(Hash)

                season_type = entry["value"].to_i
                next if season_type <= 0 || season_type == 4

                weeks = Array(entry["entries"]).filter_map do |week|
                  next unless week.is_a?(Hash)

                  number = week["value"].to_i
                  number if number.positive?
                end.uniq
                next if weeks.empty?

                CalendarPhase.build!(season_type: season_type, weeks: weeks)
              end
            end
            private_class_method :parse_season_calendar
          end
        end
      end
    end
  end
end
