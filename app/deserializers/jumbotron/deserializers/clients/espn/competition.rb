# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Competition
          class Result < CommandTower::Deserializers::Clients::Result
            field :id, type: Support.types.string, required: true
            field :uid, type: Support.types.string, nullable: true
            field :date, type: Support.types.string, nullable: true
            field :start_date, type: Support.types.string, nullable: true
            field :neutral_site, type: Support.types.boolean, nullable: true
            field :status, type: Status::Result, required: true
            field :venue, type: Venue::Result, nullable: true
            field :competitors, type: Support.types.array(Competitor::Result), required: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "competition")

            Result.build!(
              id: coerce_id(Support.payload.fetch(payload, "id")),
              uid: Support.payload.fetch(payload, "uid"),
              date: Support.payload.fetch(payload, "date"),
              start_date: Support.payload.fetch(payload, "startDate"),
              neutral_site: Support.payload.fetch(payload, "neutralSite"),
              status: Support.nest("status", Support.payload.fetch(payload, "status")) { |raw| Status.call(raw) },
              venue: Support.nest("venue", Support.payload.fetch(payload, "venue")) { |raw| Venue.call(raw) },
              competitors: map_competitors(Support.payload.fetch(payload, "competitors"))
            )
          end

          def self.coerce_id(raw)
            return raw if raw.equal?(Support.missing) || raw.nil? || raw.is_a?(String)

            raw.to_s
          end
          private_class_method :coerce_id

          def self.map_competitors(raw)
            if raw.equal?(Support.missing)
              raise CommandTower::Clients::Errors::DeserializationError.new(
                message: "competitors is required",
                details: {
                  path: "competitors",
                  expected: "Array",
                  actual: "missing",
                  rule: "required",
                  messages: ["competitors is required"]
                }
              )
            end

            unless raw.is_a?(Array)
              raise CommandTower::Clients::Errors::DeserializationError.new(
                message: "competitors must be an Array",
                details: {
                  path: "competitors",
                  expected: "Array",
                  actual: raw.class.name,
                  rule: "type",
                  messages: ["competitors must be an Array"]
                }
              )
            end

            raw.each_with_index.map do |item, index|
              Competitor.call(item)
            rescue CommandTower::Clients::Errors::DeserializationError => e
              raise CommandTower::Deserializers::Clients::Errors.prefix(e, "competitors[#{index}]")
            end
          end
          private_class_method :map_competitors
        end
      end
    end
  end
end
