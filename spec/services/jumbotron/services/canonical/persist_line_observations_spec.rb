# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::PersistLineObservations do
  describe ".call" do
    let(:game) { create(:jumbotron_game) }
    let(:event_id) { "401873278" }
    let(:competition_id) { event_id }
    let(:t0) { Time.utc(2026, 8, 13, 10, 0, 0) }
    let(:fixture_relative) { "nfl/core_odds_pre_401873278.json" }
    let(:payload) do
      JSON.parse(Jumbotron::Engine.root.join("spec/fixtures/espn", fixture_relative).read)
    end
    let(:odds) { Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::Get.call(payload) }
    let(:ingest) do
      Jumbotron::Adapters::Espn::NflHelpers::CompetitionOdds.call(
        odds,
        observed_at: t0,
        event_id: event_id,
        competition_id: competition_id
      )
    end

    before do
      create(
        :jumbotron_provider_identity,
        target: game,
        provider: "espn",
        object_namespace: "event",
        provider_id: event_id
      )
      create(
        :jumbotron_provider_identity,
        target: game,
        provider: "espn",
        object_namespace: "competition",
        provider_id: competition_id
      )
    end

    context "when ingesting the NFL pre-game fixture" do
      subject(:result) { described_class.call(ingest:) }

      it "is successful" do
        expect(result).to be_success
      end

      it "creates canonical observations" do
        expect(result.data[:observations_created]).to be > 0
        expect(Jumbotron::LineObservation.where(game: game).count).to eq(ingest.observations.size)
      end

      it "records one observation batch and no HistoricalChange rows" do
        expect(result).to be_success
        expect(Jumbotron::ObservationBatch.count).to eq(1)
        expect(Jumbotron::HistoricalChange.count).to eq(0)
      end

      it "persists spread, total, and moneyline independently" do
        expect(result).to be_success
        expect(
          Jumbotron::LineObservation.where(game: game, source: "observed").distinct.pluck(:market)
        ).to contain_exactly("spread", "total", "moneyline")
      end
    end

    context "when the same ingest is repeated later" do
      let(:later_ingest) { ingest.with(observed_at: t0 + 1.minute) }

      before { described_class.call(ingest:) }

      subject(:result) { described_class.call(ingest: later_ingest) }

      it "does not create additional historical rows" do
        expect(result.data[:observations_created]).to eq(0)
        expect(Jumbotron::LineObservation.where(game: game).count).to eq(ingest.observations.size)
      end

      it "advances observed_at without advancing changed_at" do
        expect(result).to be_success
        expect(Jumbotron::LineObservation.where(game: game).map(&:observed_at).uniq).to eq([t0 + 1.minute])
        expect(Jumbotron::LineObservation.where(game: game).map(&:changed_at).uniq).to eq([t0])
      end

      it "records a second observation batch" do
        expect(result).to be_success
        expect(Jumbotron::ObservationBatch.count).to eq(2)
      end
    end

    context "when a spread value changes on a later poll" do
      let(:changed_observations) do
        ingest.observations.map do |row|
          if row.market == "spread" && row.outcome == "home" && row.source == "observed"
            row.with(line_value: BigDecimal("-4.0"))
          else
            row
          end
        end
      end
      let(:changed_ingest) do
        ingest.with(observed_at: t0 + 2.minutes, observations: changed_observations)
      end
      let(:home_spreads) do
        Jumbotron::LineObservation.where(
          game: game,
          market: "spread",
          outcome: "home",
          source: "observed"
        ).order(:changed_at)
      end

      before do
        described_class.call(ingest:)
        described_class.call(ingest: ingest.with(observed_at: t0 + 1.minute))
      end

      subject(:result) { described_class.call(ingest: changed_ingest) }

      it "creates one new historical observation" do
        expect(result.data[:observations_created]).to eq(1)
      end

      it "records the new home spread" do
        expect(result).to be_success
        expect(home_spreads.size).to eq(2)
        expect(home_spreads.last.line_value).to eq(BigDecimal("-4.0"))
        expect(home_spreads.last.changed_at).to eq(t0 + 2.minutes)
      end
    end

    context "when persisting a two-bookmaker fixture" do
      let(:fixture_relative) { "nfl/core_odds_in_401874392.json" }
      let(:event_id) { "401874392" }

      subject(:result) { described_class.call(ingest:) }

      it "resolves two bookmakers" do
        expect(result.data[:bookmakers_resolved]).to eq(2)
        expect(Jumbotron::Bookmaker.count).to eq(2)
      end

      it "stores distinct ESPN bookmaker identities" do
        expect(result).to be_success
        expect(
          Jumbotron::ProviderIdentity.where(object_namespace: "bookmaker").pluck(:provider_id)
        ).to contain_exactly("100", "200")
      end
    end

    context "when persisting sparse soccer odds" do
      let(:fixture_relative) { "soccer/eng1/core_odds_401879301.json" }
      let(:event_id) { "401879301" }

      subject(:result) { described_class.call(ingest:) }

      it "does not create a bookmaker for an empty sparse listing" do
        expect(result).to be_success
        expect(Jumbotron::ProviderIdentity.find_by(object_namespace: "bookmaker", provider_id: "2000")).to be_nil
      end

      it "does not fabricate zero prices" do
        expect(result).to be_success
        expect(Jumbotron::LineObservation.where(game: game, price_american: 0)).to be_empty
      end

      it "persists draw moneyline from the featured book" do
        expect(result).to be_success
        expect(
          Jumbotron::LineObservation.where(game: game, market: "moneyline", outcome: "draw")
        ).not_to be_empty
      end
    end

    context "when a later poll omits moneyline" do
      let(:without_moneyline) do
        ingest.with(
          observed_at: t0 + 1.minute,
          observations: ingest.observations.reject { |row| row.market == "moneyline" }
        )
      end

      before { described_class.call(ingest:) }

      subject(:result) { described_class.call(ingest: without_moneyline) }

      it "preserves last-known moneyline history" do
        expect(result).to be_success
        expect(Jumbotron::LineObservation.where(game: game, market: "moneyline")).not_to be_empty
        expect(
          Jumbotron::LineObservation.where(game: game, market: "moneyline").map(&:changed_at).uniq
        ).to eq([t0])
      end
    end

    context "when a later poll omits a bookmaker" do
      let(:fixture_relative) { "nfl/core_odds_in_401874392.json" }
      let(:event_id) { "401874392" }
      let(:only_featured_bookmaker) do
        ingest.with(
          observed_at: t0 + 1.minute,
          observations: ingest.observations.select { |row| row.bookmaker_identity.id == "100" }
        )
      end
      let(:omitted_bookmaker) do
        Jumbotron::ProviderIdentity.find_by(object_namespace: "bookmaker", provider_id: "200").target
      end

      before { described_class.call(ingest:) }

      subject(:result) { described_class.call(ingest: only_featured_bookmaker) }

      it "keeps the omitted bookmaker and its history" do
        expect(result).to be_success
        expect(Jumbotron::Bookmaker.count).to eq(2)
        expect(Jumbotron::LineObservation.where(bookmaker: omitted_bookmaker)).not_to be_empty
      end
    end

    context "when observation insert fails" do
      before do
        allow(Jumbotron::LineObservation).to receive(:create!).and_raise(
          ActiveRecord::RecordNotUnique,
          "forced"
        )
      end

      subject(:result) { described_class.call(ingest:) }

      it "rolls back bookmakers, batches, and observations" do
        expect(result).to be_failure
        expect(Jumbotron::Bookmaker.count).to eq(0)
        expect(Jumbotron::ObservationBatch.count).to eq(0)
        expect(Jumbotron::LineObservation.count).to eq(0)
      end
    end

    context "when the competition odds collection is empty" do
      let(:fixture_relative) { "nfl/core_odds_empty.json" }

      before { allow(Jumbotron::Providers::Espn::Resources::CompetitionOdds).to receive(:acquire) }

      subject(:result) { described_class.call(ingest:) }

      it "does not call ESPN acquisition" do
        expect(result).to be_success
        expect(Jumbotron::Providers::Espn::Resources::CompetitionOdds).not_to have_received(:acquire)
      end

      it "still records an observation batch" do
        expect(result.data[:observations_created]).to eq(0)
        expect(Jumbotron::ObservationBatch.count).to eq(1)
      end
    end

    context "when the canonical game is missing" do
      let(:fixture_relative) { "nfl/core_odds_empty.json" }

      before { Jumbotron::ProviderIdentity.where(target: game).delete_all }

      subject(:result) { described_class.call(ingest:) }

      it "fails without persisting a batch" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(Jumbotron::Errors::Canonical::GameNotFoundError)
        expect(Jumbotron::ObservationBatch.count).to eq(0)
      end
    end
  end
end
