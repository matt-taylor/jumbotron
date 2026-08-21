# frozen_string_literal: true

RSpec.describe "Slice 4.2 semantic equivalence with Phase 3" do
  def current_payload(lines)
    Array(lines).map(&:to_h).sort_by do |row|
      [row[:game_id], row[:bookmaker_id], row[:market], row[:outcome]]
    end
  end

  def consensus_payload(lines)
    rows = Array(lines).map do |line|
      {
        game_id: line.game_id,
        market: line.market,
        outcome: line.outcome,
        line_value: line.line_value,
        constituent_count: line.constituent_count,
        constituents: line.constituents.map { |c| [c.bookmaker_id, c.line_observation_id] }.sort
      }
    end
    rows.sort_by { |row| [row[:game_id], row[:market], row[:outcome]] }
  end

  it "matches single-Game Current Line and Consensus across varied Games" do
    observed_early = Time.utc(2026, 8, 13, 10, 0, 0)
    observed_late = Time.utc(2026, 8, 13, 12, 0, 0)
    book_a = create(:jumbotron_bookmaker, name: "DraftKings")
    book_b = create(:jumbotron_bookmaker, name: "Bet365")
    live = create(:jumbotron_bookmaker, name: "ESPN Live Odds")

    with_history = create(:jumbotron_game)
    create(
      :jumbotron_line_observation,
      game: with_history,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-3.0"),
      observed_at: observed_early,
      changed_at: observed_early
    )
    create(
      :jumbotron_line_observation,
      game: with_history,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-4.5"),
      observed_at: observed_late,
      changed_at: observed_late
    )
    create(
      :jumbotron_line_observation,
      game: with_history,
      bookmaker: book_b,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-3.5"),
      observed_at: observed_late,
      changed_at: observed_late
    )
    create(
      :jumbotron_line_observation,
      game: with_history,
      bookmaker: book_a,
      market: "total",
      outcome: "over",
      source: "observed",
      line_value: BigDecimal("44.5"),
      observed_at: observed_late,
      changed_at: observed_late
    )

    with_stale = create(:jumbotron_game)
    create(
      :jumbotron_line_observation,
      game: with_stale,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-7.0"),
      observed_at: observed_early,
      changed_at: observed_early
    )
    create(
      :jumbotron_line_observation,
      game: with_stale,
      bookmaker: book_b,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-6.5"),
      observed_at: observed_late,
      changed_at: observed_late
    )

    with_live = create(:jumbotron_game)
    create(
      :jumbotron_line_observation,
      game: with_live,
      bookmaker: live,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-1.0"),
      observed_at: observed_late,
      changed_at: observed_late
    )
    create(
      :jumbotron_line_observation,
      game: with_live,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-2.0"),
      observed_at: observed_late,
      changed_at: observed_late
    )

    missing_lines = create(:jumbotron_game)

    tied_time = create(:jumbotron_game)
    create(
      :jumbotron_line_observation,
      game: tied_time,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-8.0"),
      observed_at: observed_late,
      changed_at: observed_late
    )
    create(
      :jumbotron_line_observation,
      game: tied_time,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-8.5"),
      observed_at: observed_late,
      changed_at: observed_late
    )
    create(
      :jumbotron_line_observation,
      game: tied_time,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "provider_open",
      line_value: BigDecimal("-99.0"),
      observed_at: observed_late,
      changed_at: observed_late
    )

    games = [with_history, with_stale, with_live, missing_lines, tied_time]
    batched_currents = Jumbotron::Services::Canonical::ResolveCurrentLinesForGames.call(
      game_ids: games.map(&:id)
    )
    expect(batched_currents).to be_success

    batched_consensus = Jumbotron::Services::Canonical::DeriveConsensusForGames.call(
      current_lines: batched_currents.data[:current_lines]
    )
    expect(batched_consensus).to be_success

    games.each do |game|
      single_currents = Jumbotron::Services::Canonical::ResolveCurrentLines.call(game: game)
      expect(single_currents).to be_success
      batched_for_game = Array(batched_currents.data[:current_lines_by_game_id][game.id])
      expect(current_payload(batched_for_game)).to eq(current_payload(single_currents.data[:current_lines]))

      single_consensus = Jumbotron::Services::Canonical::DeriveConsensusLine.call(game: game)
      expect(single_consensus).to be_success
      batched_cons_for_game = Array(batched_consensus.data[:consensus_lines]).select { |line| line.game_id == game.id }
      expect(consensus_payload(batched_cons_for_game)).to eq(consensus_payload(single_consensus.data[:consensus_lines]))
    end

    tied_lines = Array(batched_currents.data[:current_lines_by_game_id][tied_time.id])
    expect(tied_lines.map(&:line_value)).to eq([BigDecimal("-8.5")])
  end
end
