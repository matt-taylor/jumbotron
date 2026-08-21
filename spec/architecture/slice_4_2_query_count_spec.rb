# frozen_string_literal: true

RSpec.describe "Slice 4.2 query-count bounds" do
  def seed_lines(game, book_a, book_b, index)
    observed_at = Time.utc(2026, 8, 13, 12, 0, 0)
    home = create(:jumbotron_team, name: "Home #{index}")
    away = create(:jumbotron_team, name: "Away #{index}")
    create(:jumbotron_game_participant, game: game, team: home, role: "home")
    create(:jumbotron_game_participant, game: game, team: away, role: "away")
    create(
      :jumbotron_line_observation,
      game: game,
      bookmaker: book_a,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-3.0") - index,
      observed_at: observed_at,
      changed_at: observed_at
    )
    create(
      :jumbotron_line_observation,
      game: game,
      bookmaker: book_b,
      market: "spread",
      outcome: "home",
      source: "observed",
      line_value: BigDecimal("-4.0") - index,
      observed_at: observed_at,
      changed_at: observed_at
    )
  end

  def build_catalog(slate_size: 12)
    sport = create(:jumbotron_sport, name: "football")
    league = create(:jumbotron_league, sport: sport, name: "nfl")
    season = create(:jumbotron_season, league: league, name: "2026")
    phase = create(:jumbotron_season_phase, season: season, name: "regular_season")
    book_a = create(:jumbotron_bookmaker, name: "DraftKings")
    book_b = create(:jumbotron_bookmaker, name: "Bet365")
    small = create(
      :jumbotron_schedule_group,
      season: season,
      season_phase: phase,
      kind: "week",
      number: 1,
      name: "Week 1"
    )
    large = create(
      :jumbotron_schedule_group,
      season: season,
      season_phase: phase,
      kind: "week",
      number: 8,
      name: "Week 8"
    )
    one_game = create(
      :jumbotron_game,
      league: league,
      season: season,
      season_phase: phase,
      schedule_group: small,
      scheduled_at: Time.utc(2026, 9, 7, 17, 0, 0)
    )
    seed_lines(one_game, book_a, book_b, 0)
    slate = Array.new(slate_size) do |index|
      game = create(
        :jumbotron_game,
        league: league,
        season: season,
        season_phase: phase,
        schedule_group: large,
        scheduled_at: Time.utc(2026, 10, 18, 17, 0, 0) + index.hours
      )
      seed_lines(game, book_a, book_b, index + 1)
      game
    end
    { one_game: one_game, slate: slate }
  end

  def schedule_kwargs(week)
    {
      sport: "football",
      league: "nfl",
      season: "2026",
      season_phase: "regular_season",
      group: { kind: "week", number: week }
    }
  end

  def expect_bounded(one_count, slate_count, slate_size)
    expect(slate_count).to be <= one_count + 4
    expect(slate_count - one_count).to be < (slate_size - 1)
  end

  it "keeps current_lines SQL bounded as Game count grows" do
    catalog = build_catalog
    one_count = count_queries { Jumbotron.client.current_lines(game_ids: [catalog[:one_game].id]) }
    slate_count = count_queries { Jumbotron.client.current_lines(game_ids: catalog[:slate].map(&:id)) }
    expect_bounded(one_count, slate_count, 12)
  end

  it "keeps current_lines SQL bounded at 50 Games" do
    catalog = build_catalog(slate_size: 50)
    one_count = count_queries { Jumbotron.client.current_lines(game_ids: [catalog[:one_game].id]) }
    slate_count = count_queries { Jumbotron.client.current_lines(game_ids: catalog[:slate].map(&:id)) }
    expect_bounded(one_count, slate_count, 50)
  end

  it "keeps consensus SQL bounded as Game count grows" do
    catalog = build_catalog
    one_count = count_queries { Jumbotron.client.consensus(game_ids: [catalog[:one_game].id]) }
    slate_count = count_queries { Jumbotron.client.consensus(game_ids: catalog[:slate].map(&:id)) }
    expect_bounded(one_count, slate_count, 12)
  end

  it "keeps schedule include current_lines SQL bounded" do
    build_catalog
    one_count = count_queries { Jumbotron.client.schedule(**schedule_kwargs(1), include: [:current_lines]) }
    slate_count = count_queries { Jumbotron.client.schedule(**schedule_kwargs(8), include: [:current_lines]) }
    expect_bounded(one_count, slate_count, 12)
  end

  it "keeps schedule include consensus SQL bounded" do
    build_catalog
    one_count = count_queries { Jumbotron.client.schedule(**schedule_kwargs(1), include: [:consensus]) }
    slate_count = count_queries { Jumbotron.client.schedule(**schedule_kwargs(8), include: [:consensus]) }
    expect_bounded(one_count, slate_count, 12)
  end

  it "does not resolve Current Lines twice for combined schedule includes" do
    build_catalog
    currents_only = count_queries { Jumbotron.client.schedule(**schedule_kwargs(8), include: [:current_lines]) }
    both = count_queries { Jumbotron.client.schedule(**schedule_kwargs(8), include: %i[current_lines consensus]) }
    expect(both).to be <= currents_only + 1
  end

  it "does not query LineObservation for empty game_ids" do
    sqls, result = capture_queries { Jumbotron.client.current_lines(game_ids: []) }
    expect(result).to eq([])
    expect(sqls.grep(/jumbotron_line_observations/)).to be_empty
  end
end
