# frozen_string_literal: true

module Jumbotron
  module Services
    module Sandbox
      class ValidateProjectedSeason < CommandTower::Services::ApplicationService
        validate :projection, required: true
        validate :snapshot, required: true
        validate :now, required: true

        def call # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
          mappings = projection.sandbox_game_mappings.includes(
            sandbox_game: %i[sandbox_game_plan provider_identities line_observations schedule_group]
          ).to_a
          return reject("mapping coverage is incomplete") unless mapping_coverage?(mappings)
          return reject("sandbox game identity is invalid") unless mappings.all? { |mapping| valid_identity?(mapping) }

          complete = mappings.all? { |mapping| complete_state?(mapping) }
          return reject("sandbox lines or outcomes are incomplete") unless complete
          return reject("sandbox week windows overlap") unless non_overlapping?(mappings)

          start_games = mappings.filter_map do |mapping|
            game = mapping.sandbox_game
            game if game.schedule_group.number == snapshot.start_week
          end
          context.start_week_game_count = start_games.count
          context.naturally_locked_game_count = start_games.count { |game| game.scheduled_at <= now }
        end

        private

        def mapping_coverage?(mappings)
          mappings.map(&:source_game_id).sort == snapshot.games.map(&:source_game_id).sort &&
            mappings.map(&:sandbox_game_id).uniq.length == mappings.length
        end

        def valid_identity?(mapping)
          game = mapping.sandbox_game
          game.season_id == projection.sandbox_season_id &&
            game.league.name == "nfl-sandbox" &&
            game.provider_identities.any? do |identity|
              identity.provider == "sandbox" && identity.object_namespace == "event"
            end
        end

        def complete_state?(mapping) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          game = mapping.sandbox_game
          return false if game.sandbox_game_plan.nil?

          result = Jumbotron::Services::Canonical::DeriveConsensusLine.call(game: game)
          return false unless result.success?

          lines = Array(result.data[:consensus_lines])
          spread = lines.find { |line| line.market == "spread" && line.outcome == "home" }
          total = lines.find { |line| line.market == "total" && line.outcome == "over" }
          spread&.line_value == mapping.home_spread && total&.line_value == mapping.total
        end

        def non_overlapping?(mappings)
          windows = mappings.group_by { |mapping| mapping.sandbox_game.schedule_group_id }.values.map do |members|
            times = members.map { |mapping| mapping.sandbox_game.scheduled_at }
            times.minmax
          end.sort_by(&:first)
          windows.each_cons(2).all? { |left, right| left.last < right.first }
        end

        def reject(message)
          context.fail!(
            application_error: Jumbotron::Errors::Sandbox::ProjectionRejectedError.new(
              details: { code: "sandbox_projection_incomplete", message: message }
            )
          )
        end
      end
    end
  end
end
