# frozen_string_literal: true

module Jumbotron
  module Deserializers
    module Clients
      module Espn
        module CompetitionOdds
          class Get
            class Result < CommandTower::Deserializers::Clients::Result
              field :count, type: Support.types.integer, nullable: true
              field :page_index, type: Support.types.integer, nullable: true
              field :page_size, type: Support.types.integer, nullable: true
              field :page_count, type: Support.types.integer, nullable: true
              field :items, type: Support.types.array(Item::Result), required: true
            end

            def self.call(payload)
              Support.ensure_hash!(payload, label: "competition_odds")
              items_raw = Support.payload.fetch(payload, "items")

              if items_raw.equal?(Support.missing)
                raise CommandTower::Clients::Errors::DeserializationError.new(
                  message: "items is required",
                  details: {
                    path: "items",
                    expected: "Array",
                    actual: "missing",
                    rule: "required",
                    messages: ["items is required"]
                  }
                )
              end

              unless items_raw.is_a?(Array)
                raise CommandTower::Clients::Errors::DeserializationError.new(
                  message: "items must be an Array",
                  details: {
                    path: "items",
                    expected: "Array",
                    actual: items_raw.class.name,
                    rule: "type",
                    messages: ["items must be an Array"]
                  }
                )
              end

              items = items_raw.each_with_index.map do |item, index|
                Item.call(item)
              rescue CommandTower::Clients::Errors::DeserializationError => e
                raise CommandTower::Deserializers::Clients::Errors.prefix(e, "items[#{index}]")
              end

              Result.build!(
                count: Support.whole_number(Support.payload.fetch(payload, "count")),
                page_index: Support.whole_number(Support.payload.fetch(payload, "pageIndex")),
                page_size: Support.whole_number(Support.payload.fetch(payload, "pageSize")),
                page_count: Support.whole_number(Support.payload.fetch(payload, "pageCount")),
                items: items
              )
            end
          end
        end
      end
    end
  end
end
