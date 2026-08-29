# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        class Competitor
          class Result < CommandTower::Deserializers::Clients::Result
            field :id, type: Support.types.string, required: true
            field :uid, type: Support.types.string, nullable: true
            field :home_away, type: Support.types.string, required: true
            field :score, type: Support.types.string, nullable: true
            field :winner, type: Support.types.boolean, nullable: true
            field :order, type: Support.types.integer, nullable: true
            field :team, type: Team::Result, required: true
            field :records, type: Support.types.array(CompetitorRecord::Result), nullable: true
          end

          def self.call(payload)
            Support.ensure_hash!(payload, label: "competitor")

            Result.build!(
              id: coerce_id(Support.payload.fetch(payload, "id")),
              uid: Support.payload.fetch(payload, "uid"),
              home_away: Support.payload.fetch(payload, "homeAway"),
              score: coerce_score(Support.payload.fetch(payload, "score")),
              winner: Support.payload.fetch(payload, "winner"),
              order: Support.payload.fetch(payload, "order"),
              team: Support.nest("team", Support.payload.fetch(payload, "team")) { |raw| Team.call(raw) },
              records: map_records(Support.payload.fetch(payload, "records"))
            )
          end

          def self.map_records(raw)
            return nil if raw.equal?(Support.missing) || raw.nil?

            Array(raw).each_with_index.map do |item, index|
              CompetitorRecord.call(item)
            rescue CommandTower::Clients::Errors::DeserializationError => e
              raise CommandTower::Deserializers::Clients::Errors.prefix(e, "records[#{index}]")
            end
          end
          private_class_method :map_records

          def self.coerce_id(raw)
            return raw if raw.equal?(Support.missing) || raw.nil? || raw.is_a?(String)

            raw.to_s
          end
          private_class_method :coerce_id

          def self.coerce_score(raw)
            return raw if raw.equal?(Support.missing) || raw.nil? || raw.is_a?(String)

            raw.to_s
          end
          private_class_method :coerce_score
        end
      end
    end
  end
end
