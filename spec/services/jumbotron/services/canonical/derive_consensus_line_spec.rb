# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::DeriveConsensusLine do
  describe ".call" do
    let(:game) { create(:jumbotron_game) }
    let(:book_a) { create(:jumbotron_bookmaker, name: "DraftKings") }
    let(:book_b) { create(:jumbotron_bookmaker, name: "Bet365") }
    let(:first_observed_at) { Time.utc(2026, 8, 13, 10, 0, 0) }
    let(:later_observed_at) { Time.utc(2026, 8, 13, 11, 0, 0) }

    subject(:result) { described_class.call(game: game) }

    context "when two eligible bookmakers post the same spread" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.0"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_b,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-4.0"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "returns the arithmetic mean and constituent identities" do
        expect(result).to be_success
        line = result.data[:consensus_lines].find { |row| row.market == "spread" && row.outcome == "home" }
        expect(line.line_value).to eq(BigDecimal("-3.5"))
        expect(line.constituent_count).to eq(2)
        expect(line.constituents.map(&:bookmaker_id)).to contain_exactly(book_a.id, book_b.id)
        expect(line.constituents.map(&:line_observation_id)).to all(be_present)
      end
    end

    context "when spread and total are both present" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "total",
          outcome: "over",
          source: "observed",
          line_value: BigDecimal("44.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "does not mix markets" do
        expect(result.data[:consensus_lines].map(&:market)).to contain_exactly("spread", "total")
      end
    end

    context "when home and away spreads are present" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "away",
          source: "observed",
          line_value: BigDecimal("3.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "does not mix outcomes" do
        expect(result.data[:consensus_lines].map(&:outcome)).to contain_exactly("home", "away")
      end
    end

    context "when another game has observations" do
      let(:other_game) { create(:jumbotron_game) }

      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: other_game,
          bookmaker: book_b,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-10.0"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "does not mix games" do
        expect(result.data[:consensus_lines].map(&:game_id).uniq).to eq([game.id])
        expect(result.data[:consensus_lines].first.line_value).to eq(BigDecimal("-3.5"))
      end
    end

    context "when a bookmaker is omitted from the later ingest" do
      let(:book_c) { create(:jumbotron_bookmaker, name: "FanDuel") }

      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: later_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_b,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.0"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_c,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-4.0"),
          observed_at: later_observed_at,
          changed_at: first_observed_at
        )
      end

      it "keeps last-known current lines but excludes the omitted bookmaker from Consensus" do
        currents = Jumbotron::Services::Canonical::ResolveCurrentLines.call(game: game).data[:current_lines]
        expect(currents.map(&:bookmaker_id)).to contain_exactly(book_a.id, book_b.id, book_c.id)
        expect(result.data[:consensus_lines].first.constituents.map(&:bookmaker_id)).to contain_exactly(
          book_a.id, book_c.id
        )
      end
    end

    context "when an unchanged line is re-observed" do
      let(:batch) { create(:jumbotron_observation_batch) }
      let(:observation) do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          observation_batch: batch,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: later_observed_at,
          changed_at: first_observed_at
        )
      end

      before { observation }

      it "remains Consensus eligible without duplicating history" do
        expect(Jumbotron::LineObservation.where(game: game).count).to eq(1)
        expect(observation.reload.observation_batch_id).to eq(batch.id)
        expect(result.data[:consensus_lines].first.line_value).to eq(BigDecimal("-3.5"))
        expect(result.data[:consensus_lines].first.constituent_count).to eq(1)
      end
    end

    context "when a market is omitted from the later ingest" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: later_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "total",
          outcome: "over",
          source: "observed",
          line_value: BigDecimal("44.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "keeps last-known total Current Line and excludes it from Consensus" do
        currents = Jumbotron::Services::Canonical::ResolveCurrentLines.call(game: game).data[:current_lines]
        expect(currents.map(&:market)).to contain_exactly("spread", "total")
        expect(result.data[:consensus_lines].map(&:market)).to eq(["spread"])
      end
    end

    context "when a spread value changes" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-4.0"),
          observed_at: later_observed_at,
          changed_at: later_observed_at
        )
      end

      it "uses the new current observation for Consensus" do
        expect(result.data[:consensus_lines].first.line_value).to eq(BigDecimal("-4.0"))
        expect(Jumbotron::LineObservation.where(game: game).count).to eq(2)
      end
    end

    context "when the only current lines are Live Odds" do
      let(:live_book) { create(:jumbotron_bookmaker, name: "Draft Kings - Live Odds") }

      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: live_book,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.5"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "omits Consensus when there are zero eligible constituents" do
        expect(result.data[:consensus_lines]).to eq([])
      end
    end

    context "when only a draw moneyline is present" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: book_a,
          market: "moneyline",
          outcome: "draw",
          source: "observed",
          line_value: nil,
          price_american: 650,
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "exposes Current Line without a Consensus group" do
        currents = Jumbotron::Services::Canonical::ResolveCurrentLines.call(game: game).data[:current_lines]
        expect(currents.map(&:outcome)).to eq(["draw"])
        expect(result.data[:consensus_lines]).to eq([])
      end
    end
  end
end
