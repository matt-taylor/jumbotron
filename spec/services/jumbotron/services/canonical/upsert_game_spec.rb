# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::UpsertGame do
  include Jumbotron::SpecSupport::CanonicalProgress

  let(:league) { create(:jumbotron_league) }
  let(:season) { create(:jumbotron_season, league: league) }
  let(:season_phase) { create(:jumbotron_season_phase, season: season) }
  let(:observed_at) { Time.utc(2026, 8, 20, 12, 0, 0) }
  let(:change_set) { Jumbotron::Canonical::ChangeSet.new }
  let(:event_id) { "evt-progress-1" }
  let(:progress) { nil }
  let(:game_input) do
    Jumbotron::Canonical::GameInput.new(
      provider_identities: [
        Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "event", id: event_id)
      ],
      scheduled_at: Time.utc(2025, 9, 5, 0, 20, 0),
      lifecycle: "in_progress",
      neutral_site: false,
      season_year: 2025,
      season_phase_key: "regular_season",
      schedule_group: nil,
      venue: nil,
      participants: [],
      progress: progress
    )
  end

  describe ".call" do
    context "when creating a game with progress" do
      let(:progress) do
        canonical_progress(
          state: "active",
          kind: "quarter",
          number: 3,
          clock: { mode: "remaining", seconds: 261, display: "4:21" }
        )
      end

      subject(:result) do
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: observed_at,
          change_set: change_set
        )
      end

      it "persists canonical progress columns" do
        expect(result).to be_success
        expect(result.data[:game]).to have_attributes(
          progress_state: "active",
          progress_segment_kind: "quarter",
          progress_segment_number: 3,
          progress_clock_mode: "remaining",
          progress_clock_seconds: 261,
          progress_clock_display: "4:21"
        )
      end

      it "records material progress attributes on create" do
        expect(result).to be_success
        expect(change_set.map(&:attribute)).to include(
          "progress_state",
          "progress_segment_kind",
          "progress_segment_number",
          "progress_clock_mode"
        )
        expect(change_set.map(&:attribute)).not_to include(
          "progress_clock_seconds",
          "progress_clock_display"
        )
      end
    end

    context "when creating a game without progress" do
      subject(:result) do
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: observed_at,
          change_set: change_set
        )
      end

      it "leaves progress columns nil" do
        expect(result.data[:game]).to have_attributes(
          progress_state: nil,
          progress_segment_kind: nil,
          progress_segment_number: nil,
          progress_clock_mode: nil,
          progress_clock_seconds: nil,
          progress_clock_display: nil
        )
      end
    end

    context "when a later sync only moves the clock" do
      let(:later) { observed_at + 5.minutes }
      let(:clock_change_set) { Jumbotron::Canonical::ChangeSet.new }
      let(:progress) do
        canonical_progress(
          state: "active",
          kind: "quarter",
          number: 3,
          clock: { mode: "remaining", seconds: 261, display: "4:21" }
        )
      end
      let(:created_game) do
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: observed_at,
          change_set: change_set
        ).data[:game]
      end

      before do
        create(
          :jumbotron_provider_identity,
          target: created_game,
          object_namespace: "event",
          provider_id: event_id
        )
        described_class.call(
          game_input: game_input.with(
            progress: canonical_progress(
              state: "active",
              kind: "quarter",
              number: 3,
              clock: { mode: "remaining", seconds: 122, display: "2:02" }
            )
          ),
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: later,
          change_set: clock_change_set
        )
      end

      subject(:game) { created_game.reload }

      it "persists the new clock without HistoricalChange or changed_at" do
        expect(game.progress_clock_seconds).to eq(122)
        expect(game.progress_clock_display).to eq("2:02")
        expect(game.observed_at).to eq(later)
        expect(game.changed_at).to eq(observed_at)
        expect(clock_change_set).not_to be_any
      end

      it "preserves Public::Game.id across normal progress refresh (logo rotation seed)" do
        expect(game.id).to eq(created_game.id)

        public_game = Jumbotron::Services::Public::AssemblePublicGame.call(game: game).data[:public_game]
        expect(public_game.id).to eq(created_game.id)
      end
    end

    context "when a later sync repeats the same progress" do
      let(:later) { observed_at + 5.minutes }
      let(:repeat_change_set) { Jumbotron::Canonical::ChangeSet.new }
      let(:progress) do
        canonical_progress(
          state: "active",
          kind: "quarter",
          number: 3,
          clock: { mode: "remaining", seconds: 261, display: "4:21" }
        )
      end
      let(:created_game) do
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: observed_at,
          change_set: change_set
        ).data[:game]
      end

      before do
        create(
          :jumbotron_provider_identity,
          target: created_game,
          object_namespace: "event",
          provider_id: event_id
        )
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: later,
          change_set: repeat_change_set
        )
      end

      subject(:game) { created_game.reload }

      it "is idempotent aside from observed_at" do
        expect(game.progress_clock_seconds).to eq(261)
        expect(game.observed_at).to eq(later)
        expect(game.changed_at).to eq(observed_at)
        expect(repeat_change_set).not_to be_any
      end
    end

    context "when the segment number changes" do
      let(:later) { observed_at + 5.minutes }
      let(:segment_change_set) { Jumbotron::Canonical::ChangeSet.new }
      let(:progress) do
        canonical_progress(
          state: "active",
          kind: "quarter",
          number: 2,
          clock: { mode: "remaining", seconds: 0, display: "0:00" }
        )
      end
      let(:created_game) do
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: observed_at,
          change_set: change_set
        ).data[:game]
      end

      before do
        create(
          :jumbotron_provider_identity,
          target: created_game,
          object_namespace: "event",
          provider_id: event_id
        )
        described_class.call(
          game_input: game_input.with(
            progress: canonical_progress(
              state: "active",
              kind: "quarter",
              number: 3,
              clock: { mode: "remaining", seconds: 900, display: "15:00" }
            )
          ),
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: later,
          change_set: segment_change_set
        )
      end

      subject(:game) { created_game.reload }

      it "records HistoricalChange and advances changed_at" do
        expect(game.progress_segment_number).to eq(3)
        expect(game.changed_at).to eq(later)
        expect(segment_change_set.map(&:attribute)).to include("progress_segment_number")
      end
    end

    context "when progress state changes to intermission" do
      let(:later) { observed_at + 5.minutes }
      let(:state_change_set) { Jumbotron::Canonical::ChangeSet.new }
      let(:progress) do
        canonical_progress(
          state: "active",
          kind: "quarter",
          number: 2,
          clock: { mode: "remaining", seconds: 0, display: "0:00" }
        )
      end
      let(:created_game) do
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: observed_at,
          change_set: change_set
        ).data[:game]
      end

      before do
        create(
          :jumbotron_provider_identity,
          target: created_game,
          object_namespace: "event",
          provider_id: event_id
        )
        described_class.call(
          game_input: game_input.with(
            progress: canonical_progress(state: "intermission", kind: "quarter", number: 2)
          ),
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: later,
          change_set: state_change_set
        )
      end

      subject(:game) { created_game.reload }

      it "records the state change and clears the clock" do
        expect(game.progress_state).to eq("intermission")
        expect(game.progress_clock_mode).to be_nil
        expect(game.progress_clock_seconds).to be_nil
        expect(game.changed_at).to eq(later)
        expect(state_change_set.map(&:attribute)).to include("progress_state")
      end
    end

    context "when clock mode changes" do
      let(:later) { observed_at + 5.minutes }
      let(:mode_change_set) { Jumbotron::Canonical::ChangeSet.new }
      let(:progress) do
        canonical_progress(
          state: "active",
          kind: "quarter",
          number: 3,
          clock: { mode: "remaining", seconds: 261, display: "4:21" }
        )
      end
      let(:created_game) do
        described_class.call(
          game_input: game_input,
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: observed_at,
          change_set: change_set
        ).data[:game]
      end

      before do
        create(
          :jumbotron_provider_identity,
          target: created_game,
          object_namespace: "event",
          provider_id: event_id
        )
        described_class.call(
          game_input: game_input.with(
            progress: canonical_progress(
              state: "active",
              kind: "quarter",
              number: 3,
              clock: { mode: "elapsed", seconds: 261, display: "4:21" }
            )
          ),
          league: league,
          season: season,
          season_phase: season_phase,
          schedule_group: nil,
          venue: nil,
          observed_at: later,
          change_set: mode_change_set
        )
      end

      subject(:game) { created_game.reload }

      it "records HistoricalChange for progress_clock_mode" do
        expect(game.progress_clock_mode).to eq("elapsed")
        expect(game.changed_at).to eq(later)
        expect(mode_change_set.map(&:attribute)).to include("progress_clock_mode")
      end
    end
  end
end
