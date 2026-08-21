# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::ResolveCurrentLines do
  describe ".call" do
    let(:game) { create(:jumbotron_game) }
    let(:bookmaker) { create(:jumbotron_bookmaker, name: "DraftKings") }
    let(:other_bookmaker) { create(:jumbotron_bookmaker, name: "Bet365") }
    let(:first_observed_at) { Time.utc(2026, 8, 13, 10, 0, 0) }
    let(:later_observed_at) { Time.utc(2026, 8, 13, 11, 0, 0) }

    subject(:result) { described_class.call(game: game) }

    context "when multiple observed rows exist for one grain" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: bookmaker,
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
          bookmaker: bookmaker,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-4.0"),
          observed_at: later_observed_at,
          changed_at: later_observed_at
        )
      end

      it "selects the latest observed row" do
        expect(result).to be_success
        expect(result.data[:current_lines].size).to eq(1)
        expect(result.data[:current_lines].first.line_value).to eq(BigDecimal("-4.0"))
        expect(result.data[:current_lines].first.observed_at).to eq(later_observed_at)
      end
    end

    context "when provider_open is newer than observed" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: bookmaker,
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
          bookmaker: bookmaker,
          market: "spread",
          outcome: "home",
          source: "provider_open",
          line_value: BigDecimal("-7.0"),
          observed_at: later_observed_at,
          changed_at: later_observed_at
        )
      end

      it "does not use provider_open as the current line" do
        expect(result.data[:current_lines].map(&:line_value)).to eq([BigDecimal("-3.5")])
      end
    end

    context "when provider_close exists" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: bookmaker,
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
          bookmaker: bookmaker,
          market: "spread",
          outcome: "home",
          source: "provider_close",
          line_value: BigDecimal("-2.5"),
          observed_at: later_observed_at,
          changed_at: later_observed_at
        )
      end

      it "does not use provider_close as the current line" do
        expect(result.data[:current_lines].map(&:line_value)).to eq([BigDecimal("-3.5")])
      end
    end

    context "when two bookmakers have observed lines" do
      before do
        create(
          :jumbotron_line_observation,
          game: game,
          bookmaker: bookmaker,
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
          bookmaker: other_bookmaker,
          market: "spread",
          outcome: "home",
          source: "observed",
          line_value: BigDecimal("-3.0"),
          observed_at: first_observed_at,
          changed_at: first_observed_at
        )
      end

      it "keeps a current line per bookmaker" do
        expect(result.data[:current_lines].map(&:bookmaker_id)).to contain_exactly(bookmaker.id, other_bookmaker.id)
        expect(result.data[:current_lines].map(&:line_value)).to contain_exactly(
          BigDecimal("-3.5"),
          BigDecimal("-3.0")
        )
      end
    end
  end
end
