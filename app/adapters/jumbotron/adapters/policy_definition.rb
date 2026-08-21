# frozen_string_literal: true

module Jumbotron
  module Adapters
    # Frozen registry entry for one adapter-declared update policy. Not a Policy base class.
    PolicyDefinition = Data.define(:id, :type, :cadence, :eligible) do
      def eligible?(game, now:)
        raise ::Jumbotron::Adapters::ConfigurationError, "policy #{id} has no eligible predicate" if eligible.nil?

        eligible.call(game, now: now)
      end
    end
  end
end
