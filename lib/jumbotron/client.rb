# frozen_string_literal: true

module Jumbotron
  class Client
    def schedule(**)
      Public::TranslateOutcome.call(
        Workflows::ReadScheduleWorkflow.call(**),
        payload_key: :schedule
      )
    end

    def schedule_groups(**)
      Public::TranslateOutcome.call(
        Workflows::ReadScheduleGroupsWorkflow.call(**),
        payload_key: :schedule_groups
      )
    end

    def game(**)
      Public::TranslateOutcome.call(
        Workflows::ReadGameWorkflow.call(**),
        payload_key: :game
      )
    end

    def consensus(**)
      Public::TranslateOutcome.call(
        Workflows::ReadConsensusWorkflow.call(**),
        payload_key: :consensus_lines
      )
    end

    def current_lines(**)
      Public::TranslateOutcome.call(
        Workflows::ReadCurrentLinesWorkflow.call(**),
        payload_key: :current_lines
      )
    end
  end
end
