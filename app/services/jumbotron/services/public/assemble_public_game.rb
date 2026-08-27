# frozen_string_literal: true

module Jumbotron
  module Services
    module Public
      class AssemblePublicGame < CommandTower::Services::ApplicationService
        validate :game, required: true
        validate :includes, required: false
        validate :current_lines, required: false
        validate :consensus_lines, required: false

        def call
          context.public_game = build_game(game)
        end

        private

        def build_game(record)
          game_currents = Array(current_lines).select { |line| line.game_id == record.id }
          game_consensus = Array(consensus_lines).select { |line| line.game_id == record.id }
          Jumbotron::Public::Game.new(
            id: record.id,
            scheduled_at: record.scheduled_at,
            lifecycle: record.lifecycle,
            progress: build_progress(record),
            neutral_site: record.neutral_site,
            observed_at: record.observed_at,
            changed_at: record.changed_at,
            venue: build_venue(record.venue),
            participants: record.game_participants.map { |participant| build_participant(participant) },
            consensus_lines: map_consensus(game_consensus, game_currents),
            current_lines: map_currents(game_currents)
          )
        end

        def build_progress(record)
          return if record.progress_state.blank?

          Jumbotron::Public::GameProgress.new(
            state: record.progress_state,
            segment: Jumbotron::Public::GameSegment.new(
              kind: record.progress_segment_kind,
              number: record.progress_segment_number
            ),
            clock: build_clock(record)
          )
        end

        def build_clock(record)
          return if record.progress_clock_mode.nil? &&
                    record.progress_clock_seconds.nil? &&
                    record.progress_clock_display.nil?

          Jumbotron::Public::GameClock.new(
            mode: record.progress_clock_mode,
            seconds: record.progress_clock_seconds,
            display: record.progress_clock_display
          )
        end

        def build_venue(venue)
          return if venue.nil?

          Jumbotron::Public::Venue.new(id: venue.id, name: venue.name)
        end

        def build_participant(participant)
          Jumbotron::Public::Participant.new(
            role: participant.role,
            score: participant.score,
            result: participant.result,
            team: Jumbotron::Public::Team.new(
              id: participant.team.id,
              name: participant.team.name,
              key: participant.team.key
            )
          )
        end

        def map_currents(lines)
          return [] unless Array(includes).include?(:current_lines)

          lines.map do |line|
            Jumbotron::Public::CurrentLine.new(
              game_id: line.game_id,
              bookmaker_id: line.bookmaker_id,
              bookmaker_name: line.bookmaker_name,
              market: line.market,
              outcome: line.outcome,
              line_value: line.line_value,
              price_american: line.price_american,
              observed_at: line.observed_at,
              changed_at: line.changed_at
            )
          end
        end

        def map_consensus(lines, currents)
          return [] unless consensus_requested?

          with_constituents = Array(includes).include?(:consensus_constituents)
          lines.map do |line|
            Jumbotron::Public::ConsensusLine.new(
              game_id: line.game_id,
              market: line.market,
              outcome: line.outcome,
              line_value: line.line_value,
              constituent_count: line.constituent_count,
              observed_at: consensus_observed_at(line, currents),
              constituents: with_constituents ? map_constituents(line) : []
            )
          end
        end

        def consensus_requested?
          includes = Array(self.includes)
          includes.include?(:consensus) || includes.include?(:consensus_constituents)
        end

        def consensus_observed_at(line, currents)
          currents.select { |current| current.market == line.market && current.outcome == line.outcome }
                  .map(&:observed_at)
                  .compact
                  .max
        end

        def map_constituents(line)
          Array(line.constituents).map do |constituent|
            Jumbotron::Public::ConsensusConstituent.new(bookmaker_id: constituent.bookmaker_id)
          end
        end
      end
    end
  end
end
