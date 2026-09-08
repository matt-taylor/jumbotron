# frozen_string_literal: true

require "securerandom"

module Jumbotron
  module Services
    module Sandbox
      class ResolveGameObservation < CommandTower::Services::ApplicationService
        validate :game_id, required: true
        validate :observed_at, required: true

        def call
          game = resolve_game
          return if game.nil?

          plan = resolve_plan(game)
          return if plan.nil?

          assign_observation(game, plan)
        rescue ArgumentError, TypeError => e
          fail_invalid_progression(e)
        end

        private

        def resolve_game
          game = Game.find_by(id: game_id)
          return game if sandbox_game?(game)

          context.fail!(application_error: Errors::Sandbox::InvalidGameError.new)
          nil
        end

        def assign_observation(game, plan)
          game.reload
          context.plan = plan
          context.scheduled_at = game.scheduled_at
          context.observation = observation_for(game, plan)
        end

        def fail_invalid_progression(error)
          context.fail!(
            application_error: Errors::Sandbox::InvalidProgressionStateError.new(
              details: { message: error.message }
            )
          )
        end

        def sandbox_game?(game)
          return false if game.nil? || game.league.name != "nfl-sandbox"

          game.provider_identities.any? do |identity|
            identity.provider == "sandbox" && identity.object_namespace == "event"
          end
        end

        def resolve_plan(game)
          game.with_lock do
            game.reload
            game.sandbox_game_plan || create_plan(game)
          end
        end

        def create_plan(game)
          lines = Canonical::DeriveConsensusLine.call(game: game)
          return fail_missing_lines unless lines.success?

          candidates = outcome_candidates(Array(lines.data[:consensus_lines]))
          return fail_missing_lines if candidates.empty?

          selected = candidates.fetch(SecureRandom.random_number(candidates.length))
          game.create_sandbox_game_plan!(
            home_score: selected.home_score,
            away_score: selected.away_score,
            selected_at: observed_at
          )
        end

        def outcome_candidates(lines)
          spread = lines.find { |line| line.market == "spread" && line.outcome == "home" }
          total = lines.find { |line| line.market == "total" && line.outcome == "over" }
          return [] if spread.nil? || total.nil?

          Jumbotron::Adapters::Sandbox::NflHelpers::OutcomeCandidates.call(
            home_spread: spread.line_value,
            total: total.line_value
          )
        end

        def fail_missing_lines
          context.fail!(application_error: Errors::Sandbox::OutcomeLineUnavailableError.new)
          nil
        end

        def observation_for(game, plan)
          Jumbotron::Adapters::Sandbox::NflHelpers::SyntheticObservation.call(
            now: observed_at,
            kickoff: game.scheduled_at,
            plan: plan,
            current: Jumbotron::Adapters::Sandbox::NflHelpers::CurrentObservationState.call(game)
          )
        end
      end
    end
  end
end
