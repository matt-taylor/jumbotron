# frozen_string_literal: true

require "bigdecimal"

module Jumbotron
  module Adapters
    module Espn
      module NflHelpers
        class CompetitionOdds
          SOURCES = {
            "observed" => :current,
            "provider_open" => :open,
            "provider_close" => :close
          }.freeze

          def self.call(odds, observed_at:, event_id:, competition_id:)
            Canonical::LineIngestInput.new(
              observed_at: observed_at,
              provider: "espn",
              adapter_scope: "espn_nfl",
              game_identities: game_identities(event_id, competition_id),
              observations: Array(odds.items).flat_map { |item| translate_item(item) }
            )
          end

          def self.game_identities(event_id, competition_id)
            ids = []
            if event_id.present?
              ids << Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "event", id: event_id.to_s)
            end
            if competition_id.present?
              ids << Canonical::ProviderIdentityRef.new(
                provider: "espn",
                namespace: "competition",
                id: competition_id.to_s
              )
            end
            raise TransformError, "event/competition provider id required" if ids.empty?

            ids
          end
          private_class_method :game_identities

          def self.translate_item(item)
            listed = item.listed_provider
            raise TransformError, "listed provider id required" if listed.nil? || listed.id.blank?

            identity = Canonical::ProviderIdentityRef.new(
              provider: "espn",
              namespace: "bookmaker",
              id: listed.id.to_s
            )
            name = listed.name.to_s.presence || listed.id.to_s

            SOURCES.flat_map do |source, window|
              observations_for_window(item, identity, name, source, window)
            end
          end
          private_class_method :translate_item

          def self.observations_for_window(item, identity, name, source, window)
            [
              *spread_rows(item, identity, name, source, window),
              *total_rows(item, identity, name, source, window),
              *moneyline_rows(item, identity, name, source, window)
            ]
          end
          private_class_method :observations_for_window

          def self.spread_rows(item, identity, name, source, window)
            %i[home away].filter_map do |side|
              quote = team_quote(item, side, window)
              line = parse_line_value(quote&.point_spread&.american)
              price = parse_american(quote&.spread&.american)
              price ||= parse_american(item.public_send(:"#{side}_team_odds")&.spread_odds) if source == "observed"
              next if line.nil? || price.nil?

              Canonical::LineObservationInput.new(
                bookmaker_identity: identity,
                bookmaker_name: name,
                market: "spread",
                outcome: side.to_s,
                source: source,
                line_value: line,
                price_american: price
              )
            end
          end
          private_class_method :spread_rows

          def self.total_rows(item, identity, name, source, window)
            market_window = item.public_send(window)
            threshold = parse_line_value(market_window&.total&.american)
            threshold ||= parse_line_value(item.over_under) if source == "observed"
            return [] if threshold.nil?

            %i[over under].filter_map do |side|
              price = parse_american(market_window&.public_send(side)&.american)
              price ||= parse_american(item.public_send(:"#{side}_odds")) if source == "observed"
              next if price.nil?

              Canonical::LineObservationInput.new(
                bookmaker_identity: identity,
                bookmaker_name: name,
                market: "total",
                outcome: side.to_s,
                source: source,
                line_value: threshold,
                price_american: price
              )
            end
          end
          private_class_method :total_rows

          def self.moneyline_rows(item, identity, name, source, window)
            rows = %i[home away].filter_map do |side|
              quote = team_quote(item, side, window)
              price = parse_american(quote&.money_line&.american)
              price ||= parse_american(item.public_send(:"#{side}_team_odds")&.money_line) if source == "observed"
              next if price.nil?

              Canonical::LineObservationInput.new(
                bookmaker_identity: identity,
                bookmaker_name: name,
                market: "moneyline",
                outcome: side.to_s,
                source: source,
                line_value: nil,
                price_american: price
              )
            end

            draw_price = parse_american(item.public_send(window)&.draw&.american)
            draw_price ||= parse_american(item.draw_odds&.money_line) if source == "observed"
            return rows if draw_price.nil?

            rows + [
              Canonical::LineObservationInput.new(
                bookmaker_identity: identity,
                bookmaker_name: name,
                market: "moneyline",
                outcome: "draw",
                source: source,
                line_value: nil,
                price_american: draw_price
              )
            ]
          end
          private_class_method :moneyline_rows

          def self.team_quote(item, side, window)
            odds = item.public_send(:"#{side}_team_odds")
            odds&.public_send(window)
          end
          private_class_method :team_quote

          def self.parse_american(raw)
            return nil if raw.nil? || raw == ""
            return Integer(raw) if raw.is_a?(Integer)

            if raw.is_a?(Float) || raw.is_a?(BigDecimal)
              return nil unless raw == raw.to_i

              return Integer(raw)
            end

            Integer(raw.to_s.delete("+"))
          rescue ArgumentError, TypeError
            nil
          end
          private_class_method :parse_american

          def self.parse_line_value(raw)
            return nil if raw.nil? || raw == ""

            BigDecimal(raw.to_s.delete("+"))
          rescue ArgumentError, TypeError
            nil
          end
          private_class_method :parse_line_value
        end
      end
    end
  end
end
