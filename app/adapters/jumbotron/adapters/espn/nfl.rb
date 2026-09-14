# frozen_string_literal: true

module Jumbotron
  module Adapters
    module Espn
      class Nfl < Base
        TERMINAL_LIFECYCLES = %w[completed cancelled].freeze
        INTERRUPTED_LIFECYCLES = %w[postponed suspended].freeze

        adapter_id "espn_nfl"

        provider :espn
        sport "football"
        league "nfl"

        endpoint :teams,
                 resource: Providers::Espn::Resources::Teams,
                 transformer: NflHelpers::Teams

        endpoint :scoreboard,
                 resource: Providers::Espn::Resources::Scoreboard,
                 transformer: NflHelpers::Scoreboard

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

                 scheduled = game.scheduled_at
                 scheduled.between?(now + 2.weeks, now + 6.weeks)
               }

        policy :upcoming,
               type: :future_game_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)

                 scheduled = game.scheduled_at
                 scheduled > now && scheduled < now + 2.weeks
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
               eligible: lambda { |game, **|
                 INTERRUPTED_LIFECYCLES.include?(game.lifecycle)
               }

        # Bounded post-final scoreboard re-observation when post-game record is still
        # missing (Strategy B). Stops after window or once post_game is persisted.
        policy :post_final_record,
               type: :post_final_game_update,
               cadence: Cadence.new(every: 15, unit: :minute),
               eligible: lambda { |game, now:|
                 return false unless game.lifecycle == "completed"
                 return false if game.changed_at.nil? || game.changed_at < now - 6.hours

                 participants = game.game_participants
                 return false if participants.empty?

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

                 scheduled = game.scheduled_at
                 scheduled.between?(now + 2.weeks, now + 6.weeks)
               }

        policy :upcoming_lines,
               type: :future_line_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)

                 scheduled = game.scheduled_at
                 scheduled > now && scheduled < now + 2.weeks
               }

        policy :in_progress_lines,
               type: :live_line_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: lambda { |game, now:|
                 return false if TERMINAL_LIFECYCLES.include?(game.lifecycle)
                 return false if INTERRUPTED_LIFECYCLES.include?(game.lifecycle)

                 now >= game.scheduled_at
               }

        policy :interrupted_lines,
               type: :interrupted_line_update,
               cadence: Cadence.new(every: 1, unit: :hour),
               eligible: lambda { |game, **|
                 INTERRUPTED_LIFECYCLES.include?(game.lifecycle)
               }

        discovery :full_season, endpoint: :scoreboard

        register!

        def self.acquisition_scope_for(game)
          NflHelpers::AcquisitionScope.call(game)
        end

        def self.line_acquisition_scope_for(game)
          NflHelpers::LineAcquisitionScope.call(game)
        end

        def self.acquire_line_odds(acquisition)
          parts = acquisition.respond_to?(:to_h) ? acquisition.to_h : {}
          parts = parts.symbolize_keys
          Providers::Espn::Resources::CompetitionOdds.acquire(
            sport: sport,
            league: league,
            event_id: parts.fetch(:event_id),
            competition_id: parts.fetch(:competition_id)
          )
        end

        def self.translate_line_odds(odds, observed_at:, acquisition:)
          parts = acquisition.respond_to?(:to_h) ? acquisition.to_h : {}
          parts = parts.symbolize_keys
          NflHelpers::CompetitionOdds.call(
            odds,
            observed_at: observed_at,
            event_id: parts.fetch(:event_id),
            competition_id: parts.fetch(:competition_id)
          )
        end

        def self.provider_cooling_down?
          Providers::Espn::Cooldown.new.cooling_down?
        end

        def self.provider_retry_after
          Providers::Espn::Cooldown.new.retry_after
        end

        def self.scopes_for_discovery(definition)
          unless definition.endpoint == :scoreboard
            raise ConfigurationError, "#{name} discovery #{definition.id} uses unsupported endpoint"
          end

          Providers::Espn::Resources::Scoreboard.expand_full_season(
            adapter: self,
            season_year: Time.current.utc.year
          )
        end
      end
    end
  end
end
