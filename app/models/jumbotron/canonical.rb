# frozen_string_literal: true

module Jumbotron
  module Canonical
    ProviderIdentityRef = Data.define(:provider, :namespace, :id)

    TeamInput = Data.define(:provider_identities, :name, :nickname, :abbreviation) do
      def initialize(provider_identities:, name:, nickname: nil, abbreviation: nil)
        super
      end
    end

    VenueInput = Data.define(:provider_identities, :name, :city, :region) do
      def initialize(provider_identities:, name:, city: nil, region: nil)
        super
      end
    end

    ParticipantInput = Data.define(
      :provider_identities,
      :team_name,
      :role,
      :score,
      :result,
      :team_nickname,
      :team_abbreviation,
      :record_summary
    ) do
      def initialize(
        provider_identities:,
        team_name:,
        role:,
        score:,
        result:,
        team_nickname: nil,
        team_abbreviation: nil,
        record_summary: nil
      )
        super
      end
    end

    ScheduleGroupInput = Data.define(:kind, :number, :name)

    GameSegment = Data.define(:kind, :number)
    # Clock label text. Name is canonical/public contract, not Kernel#display.
    GameClock = Data.define(:mode, :seconds, :display) # rubocop:disable Lint/DataDefineOverride
    GameProgress = Data.define(:state, :segment, :clock)

    GameInput = Data.define(
      :provider_identities,
      :scheduled_at,
      :lifecycle,
      :neutral_site,
      :season_year,
      :season_phase_key,
      :schedule_group,
      :venue,
      :participants,
      :progress
    ) do
      def initialize(progress: nil, **members)
        super
      end
    end

    SyncInput = Data.define(:observed_at, :games, :teams)

    LineObservationInput = Data.define(
      :bookmaker_identity,
      :bookmaker_name,
      :market,
      :outcome,
      :source,
      :line_value,
      :price_american
    )

    LineIngestInput = Data.define(
      :observed_at,
      :provider,
      :adapter_scope,
      :game_identities,
      :observations
    )

    CurrentLine = Data.define(
      :line_observation_id,
      :game_id,
      :bookmaker_id,
      :bookmaker_name,
      :market,
      :outcome,
      :line_value,
      :price_american,
      :observed_at,
      :changed_at
    )

    ConsensusConstituent = Data.define(:line_observation_id, :bookmaker_id)

    ConsensusLine = Data.define(
      :game_id,
      :market,
      :outcome,
      :line_value,
      :constituent_count,
      :constituents
    )

    # Transaction-local accumulator for material canonical attribute changes.
    class ChangeSet
      include Enumerable

      Entry = Data.define(:subject, :attribute, :previous, :new_value)

      def initialize
        @entries = []
      end

      def record(subject:, attribute:, previous:, new_value:)
        return if serialize(previous) == serialize(new_value)

        @entries << Entry.new(
          subject: subject,
          attribute: attribute.to_s,
          previous: previous,
          new_value: new_value
        )
      end

      delegate :any?, :size, to: :entries

      def each(&)
        entries.each(&)
      end

      private

      attr_reader :entries

      def serialize(value)
        case value
        when Time, ActiveSupport::TimeWithZone
          value.iso8601
        else
          value
        end
      end
    end
  end
end
