# frozen_string_literal: true

RSpec.describe Jumbotron::Client do
  subject(:client) { Jumbotron.client }

  def build_game_graph
    sport = create(:jumbotron_sport, name: "football")
    league = create(:jumbotron_league, sport: sport, name: "nfl")
    season = create(:jumbotron_season, league: league, name: "2026")
    phase = create(:jumbotron_season_phase, season: season, name: "regular_season")
    group = create(
      :jumbotron_schedule_group,
      season: season,
      season_phase: phase,
      kind: "week",
      number: 7,
      name: "Week 7"
    )
    venue = create(:jumbotron_venue, name: "Test Stadium")
    game = create(
      :jumbotron_game,
      league: league,
      season: season,
      season_phase: phase,
      schedule_group: group,
      venue: venue,
      scheduled_at: Time.utc(2026, 10, 11, 17, 0, 0),
      lifecycle: "scheduled"
    )
    home = create(:jumbotron_team, name: "Home Team")
    away = create(:jumbotron_team, name: "Away Team")
    create(:jumbotron_game_participant, game: game, team: home, role: "home", score: 0)
    create(:jumbotron_game_participant, game: game, team: away, role: "away", score: 0)
    game
  end

  describe "#game" do
    it "returns a public Game directly" do
      game = build_game_graph
      result = client.game(id: game.id)

      expect(result).to be_a(Jumbotron::Public::Game)
      expect(result.id).to eq(game.id)
      expect(result.lifecycle).to eq("scheduled")
      expect(result.participants.map(&:role)).to contain_exactly("home", "away")
      expect(result.consensus_lines).to eq([])
      expect(result.current_lines).to eq([])
      expect(result.progress).to be_nil
      expect(result).not_to be_a(ActiveRecord::Base)
    end

    it "raises NotFoundError when the game is missing" do
      expect { client.game(id: 9_999_999) }.to raise_error(Jumbotron::NotFoundError)
    end

    it "raises InvalidRequestError for unknown includes" do
      game = build_game_graph
      expect { client.game(id: game.id, include: [:teams]) }.to raise_error(Jumbotron::InvalidRequestError)
    end

    it "composes consensus without a second client call" do
      game = build_game_graph
      book = create(:jumbotron_bookmaker, name: "DraftKings")
      observed_at = Time.utc(2026, 8, 13, 12, 0, 0)
      create(
        :jumbotron_line_observation,
        game: game,
        bookmaker: book,
        market: "spread",
        outcome: "home",
        source: "observed",
        line_value: BigDecimal("-3.5"),
        observed_at: observed_at,
        changed_at: observed_at
      )

      result = client.game(id: game.id, include: [:consensus])
      expect(result.consensus_lines.size).to eq(1)
      expect(result.consensus_lines.first.line_value).to eq(BigDecimal("-3.5"))
      expect(result.current_lines).to eq([])
    end

    context "when the game has canonical progress" do
      let(:game) { build_game_graph }

      before do
        game.update!(
          lifecycle: "in_progress",
          progress_state: "active",
          progress_segment_kind: "quarter",
          progress_segment_number: 3,
          progress_clock_mode: "remaining",
          progress_clock_seconds: 261,
          progress_clock_display: "4:21"
        )
      end

      subject(:result) { client.game(id: game.id) }

      it "returns nested progress" do
        expect(result.progress).to be_a(Jumbotron::Public::GameProgress)
        expect(result.progress.state).to eq("active")
        expect(result.progress.segment).to have_attributes(kind: "quarter", number: 3)
        expect(result.progress.clock).to have_attributes(mode: "remaining", seconds: 261, display: "4:21")
        expect(result.progress).not_to be_a(ActiveRecord::Base)
      end
    end
  end

  describe "#schedule_groups" do
    let(:sport) { create(:jumbotron_sport, name: "football") }
    let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
    let(:season) { create(:jumbotron_season, league: league, name: "2026") }
    let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }

    context "when the phase has observed week and round groups" do
      let!(:later_week) do
        create(
          :jumbotron_schedule_group,
          season: season,
          season_phase: phase,
          kind: "week",
          number: 2,
          name: "Week 2"
        )
      end
      let!(:earlier_week) do
        create(
          :jumbotron_schedule_group,
          season: season,
          season_phase: phase,
          kind: "week",
          number: 1,
          name: "Week 1"
        )
      end

      before do
        create(
          :jumbotron_schedule_group,
          season: season,
          season_phase: phase,
          kind: "round",
          number: 1,
          name: "Round 1"
        )
      end

      subject(:result) do
        client.schedule_groups(
          sport: "football",
          league: "nfl",
          season: "2026",
          season_phase: "regular_season",
          kind: "week"
        )
      end

      it "returns observed groups ordered by number with incompleteness" do
        expect(result).to be_a(Jumbotron::Public::ScheduleGroupEnumeration)
        expect(result.completeness).to eq(:incomplete)
        expect(result.groups.map(&:number)).to eq([1, 2])
        expect(result.groups.map(&:id)).to eq([earlier_week.id, later_week.id])
        expect(result.groups).to all(be_a(Jumbotron::Public::ScheduleGroup))
        expect(result.groups.first).not_to be_a(ActiveRecord::Base)
      end
    end

    context "when the phase has no groups" do
      before { phase }

      subject(:result) do
        client.schedule_groups(
          sport: "football",
          league: "nfl",
          season: "2026",
          season_phase: "regular_season"
        )
      end

      it "returns empty incomplete" do
        expect(result.groups).to eq([])
        expect(result.completeness).to eq(:incomplete)
      end
    end

    context "when the season phase is unresolved" do
      before { season }

      subject(:call) do
        client.schedule_groups(
          sport: "football",
          league: "nfl",
          season: "2026",
          season_phase: "missing_phase"
        )
      end

      it "raises NotFoundError" do
        expect { call }.to raise_error(Jumbotron::NotFoundError)
      end
    end

    context "when season_phase is missing" do
      subject(:call) { client.schedule_groups(sport: "football", league: "nfl", season: "2026") }

      it "raises InvalidRequestError" do
        expect { call }.to raise_error(Jumbotron::InvalidRequestError)
      end
    end

    context "when EnsureScheduleGroup has created a group" do
      before do
        Jumbotron::Services::Canonical::EnsureScheduleGroup.call(
          season: season,
          season_phase: phase,
          schedule_group_input: Jumbotron::Canonical::ScheduleGroupInput.new(
            kind: "week",
            number: 1,
            name: "Week 1"
          )
        )
      end

      subject(:result) do
        client.schedule_groups(
          sport: "football",
          league: "nfl",
          season: "2026",
          season_phase: "regular_season",
          kind: "week"
        )
      end

      it "stays incomplete" do
        expect(result.groups.map(&:number)).to eq([1])
        expect(result.completeness).to eq(:incomplete)
      end
    end
  end

  describe "#schedule" do
    it "returns games for an objective group" do
      game = build_game_graph
      result = client.schedule(
        sport: "football",
        league: "nfl",
        season: "2026",
        season_phase: "regular_season",
        group: { kind: "week", number: 7 }
      )

      expect(result).to be_a(Jumbotron::Public::Schedule)
      expect(result.games.map(&:id)).to eq([game.id])
      expect(result.group.kind).to eq("week")
      expect(result.group.number).to eq(7)
      expect(result.games.first.consensus_lines).to eq([])
      expect(result.games.first.progress).to be_nil
    end

    context "when a schedule game has canonical progress" do
      let(:game) { build_game_graph }

      before do
        game.update!(
          lifecycle: "in_progress",
          progress_state: "intermission",
          progress_segment_kind: "quarter",
          progress_segment_number: 2
        )
      end

      subject(:result) do
        client.schedule(
          sport: "football",
          league: "nfl",
          season: "2026",
          season_phase: "regular_season",
          group: { kind: "week", number: 7 }
        )
      end

      it "includes nested progress on schedule games" do
        expect(result.games.first.progress.state).to eq("intermission")
        expect(result.games.first.progress.segment).to have_attributes(kind: "quarter", number: 2)
        expect(result.games.first.progress.clock).to be_nil
      end
    end

    it "returns an empty games list when the range has no games" do
      game = build_game_graph
      result = client.schedule(
        league_id: game.league_id,
        starts_at: Time.utc(2010, 1, 1),
        ends_at: Time.utc(2010, 1, 2)
      )
      expect(result.games).to eq([])
    end

    it "rejects group and time together" do
      game = build_game_graph
      expect do
        client.schedule(
          league_id: game.league_id,
          season: "2026",
          season_phase: "regular_season",
          group: { kind: "week", number: 7 },
          starts_at: Time.utc(2026, 10, 1),
          ends_at: Time.utc(2026, 10, 31)
        )
      end.to raise_error(Jumbotron::InvalidRequestError)
    end

    it "selects by time range" do
      game = build_game_graph
      result = client.schedule(
        league_id: game.league_id,
        starts_at: Time.utc(2026, 10, 11, 0, 0, 0),
        ends_at: Time.utc(2026, 10, 12, 0, 0, 0)
      )
      expect(result.games.map(&:id)).to eq([game.id])
    end
  end

  describe "#current_lines and #consensus" do
    it "returns public line collections for canonical game ids" do
      game = build_game_graph
      book_a = create(:jumbotron_bookmaker, name: "DraftKings")
      book_b = create(:jumbotron_bookmaker, name: "Bet365")
      observed_at = Time.utc(2026, 8, 13, 12, 0, 0)
      create(
        :jumbotron_line_observation,
        game: game,
        bookmaker: book_a,
        market: "spread",
        outcome: "home",
        source: "observed",
        line_value: BigDecimal("-3.0"),
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
        line_value: BigDecimal("-5.0"),
        observed_at: observed_at,
        changed_at: observed_at
      )

      currents = client.current_lines(game_ids: [game.id])
      expect(currents).to all(be_a(Jumbotron::Public::CurrentLine))
      expect(currents.map(&:line_value)).to contain_exactly(BigDecimal("-3.0"), BigDecimal("-5.0"))

      consensus = client.consensus(game_ids: [game.id])
      expect(consensus).to all(be_a(Jumbotron::Public::ConsensusLine))
      expect(consensus.first.line_value).to eq(BigDecimal("-4.0"))
      expect(consensus.first.constituents).to eq([])
    end

    it "omits unknown game ids from batch reads" do
      expect(client.current_lines(game_ids: [9_999_999])).to eq([])
      expect(client.consensus(game_ids: [9_999_999])).to eq([])
    end

    it "returns empty collections for empty game_ids without error" do
      expect(client.current_lines(game_ids: [])).to eq([])
      expect(client.consensus(game_ids: [])).to eq([])
    end
  end

  describe "#register_sandbox_projection" do
    let(:sport) { create(:jumbotron_sport, name: "football") }
    let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
    let(:season) { create(:jumbotron_season, league: league, name: "2026") }
    let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }

    before do
      phase
    end

    subject(:result) do
      client.register_sandbox_projection(
        name: "apple-review",
        source: {
          sport: "football",
          league: "nfl",
          season: "2026",
          season_phase: "regular_season"
        }
      )
    end

    it "returns an immutable public projection directly" do
      expect(result).to be_a(Jumbotron::Public::SandboxProjection)
      expect(result.name).to eq("apple-review")
      expect(result).not_to be_a(ActiveRecord::Base)
    end

    it "retains stable code and safe details on public errors" do
      expect do
        client.register_sandbox_projection(name: "apple-review", source: "nfl")
      end.to raise_error(Jumbotron::InvalidRequestError) { |error| expect(error.code).to eq("invalid_request") }
    end
  end

  describe "#sandbox_projection" do
    let(:projection) { create(:jumbotron_sandbox_projection, name: "apple-review") }

    before { projection }

    subject(:result) { client.sandbox_projection(name: "apple-review") }

    it "returns an immutable named projection read" do
      expect(result).to be_a(Jumbotron::Public::SandboxProjection)
      expect(result.name).to eq("apple-review")
      expect(result.source_label).to be_present
      expect(result).not_to be_a(ActiveRecord::Base)
    end

    context "when missing" do
      subject(:call) { client.sandbox_projection(name: "missing") }

      it { expect { call }.to raise_error(Jumbotron::NotFoundError) }
    end
  end
end
