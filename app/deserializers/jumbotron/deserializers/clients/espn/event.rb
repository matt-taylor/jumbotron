# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Event
          class Result < CommandTower::Deserializers::Clients::Result
            field :id, type: Support.types.string, required: true
            field :uid, type: Support.types.string, nullable: true
            field :date, type: Support.types.string, required: true
            field :name, type: Support.types.string, required: true
            field :short_name, type: Support.types.string, nullable: true
            field :season, type: Season::Result, nullable: true
            field :week, type: Week::Result, nullable: true
            field :status, type: Status::Result, nullable: true
            field :competitions, type: Support.types.array(Competition::Result), required: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "event")

            Result.build!(
              id: coerce_id(Support.payload.fetch(payload, "id")),
              uid: Support.payload.fetch(payload, "uid"),
              date: Support.payload.fetch(payload, "date"),
              name: Support.payload.fetch(payload, "name"),
              short_name: Support.payload.fetch(payload, "shortName"),
              season: Support.nest("season", Support.payload.fetch(payload, "season")) { |raw| Season.call(raw) },
              week: Support.nest("week", Support.payload.fetch(payload, "week")) { |raw| Week.call(raw) },
              status: Support.nest("status", Support.payload.fetch(payload, "status")) { |raw| Status.call(raw) },
              competitions: map_competitions(Support.payload.fetch(payload, "competitions"))
            )
          end

          def self.coerce_id(raw)
            return raw if raw.equal?(Support.missing) || raw.nil? || raw.is_a?(String)

            raw.to_s
          end
          private_class_method :coerce_id

          def self.map_competitions(raw)
            if raw.equal?(Support.missing)
              raise CommandTower::Clients::Errors::DeserializationError.new(
                message: "competitions is required",
                details: {
                  path: "competitions",
                  expected: "Array",
                  actual: "missing",
                  rule: "required",
                  messages: ["competitions is required"]
                }
              )
            end

            unless raw.is_a?(Array)
              raise CommandTower::Clients::Errors::DeserializationError.new(
                message: "competitions must be an Array",
                details: {
                  path: "competitions",
                  expected: "Array",
                  actual: raw.class.name,
                  rule: "type",
                  messages: ["competitions must be an Array"]
                }
              )
            end

            raw.each_with_index.map do |item, index|
              Competition.call(item)
            rescue CommandTower::Clients::Errors::DeserializationError => e
              raise CommandTower::Deserializers::Clients::Errors.prefix(e, "competitions[#{index}]")
            end
          end
          private_class_method :map_competitions
        end
      end
    end
  end
end
