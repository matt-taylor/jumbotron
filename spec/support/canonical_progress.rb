# frozen_string_literal: true

module Jumbotron
  module SpecSupport
    module CanonicalProgress
      def canonical_progress(state:, kind:, number:, clock: nil)
        built_clock = clock && Jumbotron::Canonical::GameClock.new(**clock)
        Jumbotron::Canonical::GameProgress.new(
          state: state,
          segment: Jumbotron::Canonical::GameSegment.new(kind: kind, number: number),
          clock: built_clock
        )
      end
    end
  end
end
