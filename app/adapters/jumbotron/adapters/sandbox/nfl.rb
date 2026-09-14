# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Sandbox
      class Nfl < Base
        TERMINAL_LIFECYCLES = %w[completed cancelled].freeze
        INTERRUPTED_LIFECYCLES = %w[postponed suspended].freeze

        adapter_id "sandbox_nfl"

        provider :sandbox
        sport "football"
        league "nfl-sandbox"

        endpoint :scoreboard,
                 resource: Providers::Sandbox::Resources::Scoreboard,
                 transformer: NflHelpers::Scoreboard
        endpoint :projection,
                 resource: Providers::Sandbox::Resources::Projection,
                 transformer: NflHelpers::Projection

        policy :far_future,
               type: :future_game_update,
               cadence: Cadence.new(every: 1, unit: :week),
               eligible: lambda { |game, now:|
                 TERMINAL_LIFECYCLES.exclude?(game.lifecycle) &&
                   game.scheduled_at > now + 6.weeks
               }

        policy :near_future,
               type: :future_game_update,
               cadence: Cadence.new(every: 1, unit: :day),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)

                 game.scheduled_at.between?(now + 2.weeks, now + 6.weeks)
               }

        policy :upcoming,
               type: :future_game_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)

                 game.scheduled_at > now && game.scheduled_at < now + 2.weeks
               }

        policy :live,
               type: :live_game_update,
               cadence: Cadence.new(every: 30, unit: :second),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)
                 return false if INTERRUPTED_LIFECYCLES.include?(game.lifecycle)

                 now >= game.scheduled_at
               }

        policy :interrupted,
               type: :interrupted_game_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: ->(game, **) { INTERRUPTED_LIFECYCLES.include?(game.lifecycle) }

        policy :post_final_record,
               type: :post_final_game_update,
               cadence: Cadence.new(every: 15, unit: :minute),
               eligible: lambda { |game, now:|
                 return false unless game.lifecycle == "completed"
                 return false if game.changed_at.nil? || game.changed_at < now - 6.hours

                 participants = game.game_participants
                 participants.present? &&
                   participants.any? { |participant| participant.record_summary_post_game.blank? }
               }

        policy :far_future_lines,
               type: :future_line_update,
               cadence: Cadence.new(every: 1, unit: :week),
               eligible: lambda { |game, now:|
                 TERMINAL_LIFECYCLES.exclude?(game.lifecycle) &&
                   game.scheduled_at > now + 6.weeks
               }

        policy :near_future_lines,
               type: :future_line_update,
               cadence: Cadence.new(every: 1, unit: :day),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)

                 game.scheduled_at.between?(now + 2.weeks, now + 6.weeks)
               }

        policy :upcoming_lines,
               type: :future_line_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)

                 game.scheduled_at > now && game.scheduled_at < now + 2.weeks
               }

        policy :in_progress_lines,
               type: :live_line_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: lambda { |game, now:|
                 game.lifecycle == "in_progress" && now >= game.scheduled_at
               }

        policy :interrupted_lines,
               type: :interrupted_line_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: ->(game, **) { INTERRUPTED_LIFECYCLES.include?(game.lifecycle) }

        register!

        def self.acquisition_scope_for(game)
          NflHelpers::AcquisitionScope.call(game)
        end

        def self.line_acquisition_scope_for(game)
          NflHelpers::LineAcquisitionScope.call(game)
        end

        def self.acquire_line_odds(acquisition)
          parts = acquisition.to_h.symbolize_keys
          Providers::Sandbox::Resources::CompetitionOdds.acquire(adapter: self, **parts)
        end

        def self.translate_line_odds(odds, observed_at:, acquisition:)
          NflHelpers::CompetitionOdds.call(odds, observed_at: observed_at, acquisition: acquisition)
        end
      end
    end
  end
end
