# frozen_string_literal: true

RSpec.describe Jumbotron::Providers::Espn::Resources do
  after { Jumbotron::Clients.reset_providers! }

  let(:fixture_root) { Jumbotron::Engine.root.join("spec/fixtures/espn/nfl") }
  let(:scoreboard_body) { fixture_root.join("scoreboard_2025_w1.json").read }
  let(:teams_body) { fixture_root.join("teams.json").read }

  let(:adapter) { Jumbotron::Adapters::Espn::Nfl }

  describe "Scoreboard" do
    let(:transport) do
      Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(
          status: 200,
          body: scoreboard_body,
          duration_ms: 1
        )
      end
    end

    before { Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport)) }

    it "passes adapter sport/league into the ESPN client and returns typed POROs" do
      result = described_class::Scoreboard.acquire(adapter: adapter, dates: 2025, season_type: 2, week: 1)

      expect(result).to be_success
      expect(result.output).to be_a(Jumbotron::Deserializers::Clients::Espn::Scoreboard::Get::Result)
      expect(transport.calls.first.url).to include("football/nfl/scoreboard")
      expect(transport.calls.first.query).to include("dates" => 2025, "seasontype" => 2, "week" => 1)
    end

    it "does not perform translation or persistence" do
      expect(Jumbotron::Game).not_to receive(:create!)
      described_class::Scoreboard.acquire(adapter: adapter)
    end

    it "skips HTTP when ESPN cooldown is active" do
      Jumbotron::Providers::Espn::Cooldown.new.record_failure!(
        CommandTower::Clients::Errors::UpstreamError.new(message: "down", details: { status: 503 })
      )

      result = described_class::Scoreboard.acquire(adapter: adapter, dates: 2025, season_type: 2, week: 1)

      expect(result).to be_failure
      expect(result.error).to be_a(Jumbotron::Providers::Espn::CooldownActiveError)
      expect(transport.calls).to be_empty
    end

    it "resets cooldown after a successful acquisition" do
      cooldown = Jumbotron::Providers::Espn::Cooldown.new
      cooldown.record_failure!(
        CommandTower::Clients::Errors::UpstreamError.new(message: "down", details: { status: 503 }),
        now: Time.current - 6
      )
      expect(cooldown.failure_count).to eq(1)

      result = described_class::Scoreboard.acquire(adapter: adapter, dates: 2025, season_type: 2, week: 1)

      expect(result).to be_success
      expect(cooldown.failure_count).to eq(0)
      expect(cooldown.cooling_down?).to be(false)
    end

    it "expands full-season discovery from ESPN calendar into seasontype+week requests" do
      result = described_class::Scoreboard.acquire_full_season(adapter: adapter, season_year: 2025)

      expect(result).to be_success
      queries = transport.calls.map(&:query)
      expect(queries.first).to eq("dates" => 2025)
      week_queries = queries.drop(1)
      expect(week_queries).to include(
        { "dates" => 2025, "seasontype" => 1, "week" => 1 },
        { "dates" => 2025, "seasontype" => 2, "week" => 18 },
        { "dates" => 2025, "seasontype" => 3, "week" => 5 }
      )
      expect(week_queries.size).to eq(4 + 18 + 5)
      expect(result.output.events.map(&:id).uniq.size).to eq(result.output.events.size)
    end

    it "returns calendar week acquisitions from expand_full_season without concatenating events" do
      result = described_class::Scoreboard.expand_full_season(adapter: adapter, season_year: 2025)

      expect(result).to be_success
      expect(transport.calls.size).to eq(1)
      expect(transport.calls.first.query).to eq("dates" => 2025)
      expect(result.output).to include(
        { dates: 2025, season_type: 1, week: 1 },
        { dates: 2025, season_type: 2, week: 18 },
        { dates: 2025, season_type: 3, week: 5 }
      )
      expect(result.output.size).to eq(4 + 18 + 5)
      expect(result.output).not_to respond_to(:events)
    end

    it "fails full-season discovery when the calendar is missing" do
      empty = Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(
          status: 200,
          body: { "events" => [] }.to_json,
          duration_ms: 1
        )
      end
      Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: empty))

      result = described_class::Scoreboard.acquire_full_season(adapter: adapter, season_year: 2025)

      expect(result).to be_failure
      expect(result.error.message).to include("calendar missing")
    end
  end

  describe "Teams" do
    let(:transport) do
      Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(
          status: 200,
          body: teams_body,
          duration_ms: 1
        )
      end
    end

    before { Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport)) }

    it "passes adapter sport/league into the ESPN client" do
      result = described_class::Teams.acquire(adapter: adapter)

      expect(result).to be_success
      expect(result.output).to be_an(Array)
      expect(result.output.first).to be_a(Jumbotron::Deserializers::Clients::Espn::Team::Result)
      expect(transport.calls.first.url).to include("football/nfl/teams")
    end
  end

  describe "CompetitionOdds" do
    let(:odds_body) { fixture_root.join("core_odds_in_401874392.json").read }

    let(:transport) do
      Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(
          status: 200,
          body: odds_body,
          duration_ms: 1
        )
      end
    end

    before { Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport)) }

    def acquire
      described_class::CompetitionOdds.acquire(
        sport: "football",
        league: "nfl",
        event_id: "401874392",
        competition_id: "401874392"
      )
    end

    it "passes scalar identities into the ESPN client and returns typed POROs" do
      result = acquire

      expect(result).to be_success
      expect(result.output.items.size).to eq(2)
      expect(transport.calls.first.url).to include(
        "sports/football/leagues/nfl/events/401874392/competitions/401874392/odds"
      )
    end

    it "skips HTTP when ESPN cooldown is active" do
      Jumbotron::Providers::Espn::Cooldown.new.record_failure!(
        CommandTower::Clients::Errors::UpstreamError.new(message: "down", details: { status: 503 })
      )

      result = acquire

      expect(result).to be_failure
      expect(result.error).to be_a(Jumbotron::Providers::Espn::CooldownActiveError)
      expect(transport.calls).to be_empty
    end

    it "does not advance cooldown on deserialization failure" do
      bad = Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(
          status: 200,
          body: { "count" => 1 }.to_json,
          duration_ms: 1
        )
      end
      Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: bad))

      result = acquire
      cooldown = Jumbotron::Providers::Espn::Cooldown.new

      expect(result).to be_failure
      expect(result.error).to be_a(CommandTower::Clients::Errors::DeserializationError)
      expect(cooldown.cooling_down?).to be(false)
      expect(cooldown.failure_count).to eq(0)
    end

    it "advances cooldown on 5xx availability failure" do
      down = Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(status: 503, body: "{}", duration_ms: 1)
      end
      Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: down))

      result = acquire
      cooldown = Jumbotron::Providers::Espn::Cooldown.new

      expect(result).to be_failure
      expect(cooldown.cooling_down?).to be(true)
    end
  end

  describe "resource reuse across adapters" do
    let(:transport) do
      Jumbotron::SpecSupport::FakeTransport.new do |_request|
        CommandTower::Clients::Transport::Response.build(
          status: 200,
          body: scoreboard_body,
          duration_ms: 1
        )
      end
    end

    let(:college_adapter) do
      Class.new(Jumbotron::Adapters::Base) do
        def self.name
          "Jumbotron::Adapters::Espn::SpecCollege"
        end

        provider :espn
        sport "football"
        league "college-football"
      end
    end

    before do
      stub_const("Jumbotron::Adapters::Espn::SpecCollege", college_adapter)
      Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))
    end

    it "binds sport/league from the adapter, not from the resource class" do
      Jumbotron::Providers::Espn::Resources::Scoreboard.acquire(adapter: college_adapter)

      expect(transport.calls.first.url).to include("football/college-football/scoreboard")
    end
  end
end
