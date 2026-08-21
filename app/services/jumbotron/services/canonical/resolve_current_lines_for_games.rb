# frozen_string_literal: true

module Jumbotron
  module Services
    module Canonical
      class ResolveCurrentLinesForGames < CommandTower::Services::ApplicationService
        GRAIN = %i[game_id bookmaker_id market outcome source].freeze

        validate :game_ids, required: false

        def call
          ids = Array(game_ids).map(&:to_i).uniq
          if ids.empty?
            context.current_lines = []
            context.current_lines_by_game_id = {}
            return
          end

          lines = latest_observed(ids).map { |row| to_current_line(row) }
          context.current_lines = lines
          context.current_lines_by_game_id = lines.group_by(&:game_id)
        end

        private

        def latest_observed(ids)
          scope = LineObservation.where(game_id: ids, source: "observed")
          observation_ids = scope.joins(latest_observed_at_join(scope)).group(*GRAIN).maximum(:id).values
          return [] if observation_ids.empty?

          LineObservation.where(id: observation_ids).includes(:bookmaker).to_a
        end

        def latest_observed_at_join(scope)
          observations = LineObservation.arel_table
          max_observed = scope.select(
            *GRAIN,
            observations[:observed_at].maximum.as("observed_at")
          ).group(*GRAIN)

          <<~SQL.squish
            INNER JOIN (#{max_observed.to_sql}) latest
              ON jumbotron_line_observations.game_id = latest.game_id
             AND jumbotron_line_observations.bookmaker_id = latest.bookmaker_id
             AND jumbotron_line_observations.market = latest.market
             AND jumbotron_line_observations.outcome = latest.outcome
             AND jumbotron_line_observations.source = latest.source
             AND jumbotron_line_observations.observed_at = latest.observed_at
          SQL
        end

        def to_current_line(row)
          Jumbotron::Canonical::CurrentLine.new(
            line_observation_id: row.id,
            game_id: row.game_id,
            bookmaker_id: row.bookmaker_id,
            bookmaker_name: row.bookmaker.name,
            market: row.market,
            outcome: row.outcome,
            line_value: row.line_value,
            price_american: row.price_american,
            observed_at: row.observed_at,
            changed_at: row.changed_at
          )
        end
      end
    end
  end
end
