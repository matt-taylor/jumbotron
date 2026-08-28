# frozen_string_literal: true

RSpec.describe "Jumbotron::Adapters::Espn::NflHelpers transformers" do
  include Jumbotron::SpecSupport::EspnScoreboardOverlay

  after { Jumbotron::Clients.reset_providers! }

  let(:fixture_root) { Jumbotron::Engine.root.join("spec/fixtures/espn/nfl") }
  let(:observed_at) { Time.utc(2026, 8, 12, 12, 0, 0) }

  def acquire_scoreboard(body)
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(status: 200, body: body, duration_ms: 1)
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))
    Jumbotron::Clients.espn.scoreboard.get(sport: "football", league: "nfl").output
  end

  def acquire_teams(body)
    transport = Jumbotron::SpecSupport::FakeTransport.new do |_request|
      CommandTower::Clients::Transport::Response.build(status: 200, body: body, duration_ms: 1)
    end
    Jumbotron::Clients.seed_provider!(:espn, Jumbotron::Clients::Espn.new(transport: transport))
    Jumbotron::Clients.espn.teams.get(sport: "football", league: "nfl").output
  end

  describe Jumbotron::Adapters::Espn::NflHelpers::Scoreboard do
    it "maps fixtures into Canonical::SyncInput without touching AR" do
      board = acquire_scoreboard(fixture_root.join("scoreboard_2025_w1.json").read)

      expect(Jumbotron::Game).not_to receive(:create!)
      input = described_class.call(board, observed_at: observed_at)

      expect(input).to be_a(Jumbotron::Canonical::SyncInput)
      expect(input.games).not_to be_empty
      game = input.games.first
      expect(game.lifecycle).to eq("completed")
      expect(game.season_phase_key).to eq("regular_season")
      expect(game.schedule_group).to have_attributes(kind: "week", number: 1, name: "Week 1")
      expect(game.provider_identities.map(&:namespace)).to include("event", "competition")
      expect(game.participants.map(&:role)).to contain_exactly("home", "away")
      expect(game.scheduled_at).to be_a(Time)
    end

    context "when the scoreboard fixture is scheduled" do
      let(:board) { acquire_scoreboard(fixture_root.join("scoreboard_2026_pre.json").read) }

      subject(:input) { described_class.call(board, observed_at: observed_at) }

      it "maps to lifecycle scheduled with nil progress" do
        expect(input.games.first.lifecycle).to eq("scheduled")
        expect(input.games.first.progress).to be_nil
      end
    end

    context "when the scoreboard fixture is final" do
      let(:board) { acquire_scoreboard(fixture_root.join("scoreboard_2025_w1.json").read) }

      subject(:progress) { described_class.call(board, observed_at: observed_at).games.first.progress }

      it "retains completed progress" do
        expect(progress.state).to eq("active")
        expect(progress.segment).to have_attributes(kind: "quarter", number: 4)
        expect(progress.clock).to have_attributes(mode: "remaining", seconds: 0, display: "0:00")
      end
    end

    context "when a regulation in-progress status is overlaid" do
      let(:board) { acquire_scoreboard(espn_scoreboard_with_status("status_in_progress_q3.json")) }

      subject(:progress) { described_class.call(board, observed_at: observed_at).games.first.progress }

      it "maps to quarter progress" do
        expect(progress.state).to eq("active")
        expect(progress.segment).to have_attributes(kind: "quarter", number: 3)
        expect(progress.clock).to have_attributes(seconds: 261, display: "4:21")
      end
    end

    context "when an intermission status is overlaid" do
      let(:board) { acquire_scoreboard(espn_scoreboard_with_status("status_halftime.json")) }

      subject(:progress) { described_class.call(board, observed_at: observed_at).games.first.progress }

      it "maps to quarter 2 without a clock" do
        expect(progress.state).to eq("intermission")
        expect(progress.segment).to have_attributes(kind: "quarter", number: 2)
        expect(progress.clock).to be_nil
      end
    end

    context "when an overtime status is overlaid" do
      let(:board) { acquire_scoreboard(espn_scoreboard_with_status("status_overtime.json")) }

      subject(:progress) { described_class.call(board, observed_at: observed_at).games.first.progress }

      it "maps to overtime 1" do
        expect(progress.segment).to have_attributes(kind: "overtime", number: 1)
      end
    end

    it "fails on unknown ESPN status" do
      expect do
        Jumbotron::Adapters::Espn::NflHelpers::Lifecycle.call("STATUS_WEIRD")
      end.to raise_error(Jumbotron::Adapters::TransformError, /unsupported ESPN status/)
    end

    context "when mapping participant nicknames from scoreboard teams" do
      let(:board) { acquire_scoreboard(fixture_root.join("scoreboard_2025_w1.json").read) }

      subject(:nicknames) do
        described_class.call(board, observed_at: observed_at).games.first.participants.map(&:team_nickname)
      end

      it "fills team_nickname from provider name when ESPN nickname is absent" do
        expect(nicknames).to contain_exactly("Eagles", "Cowboys")
      end
    end
  end

  describe Jumbotron::Adapters::Espn::NflHelpers::Teams do
    it "maps team POROs into SyncInput team subjects" do
      teams = acquire_teams(fixture_root.join("teams.json").read)
      input = described_class.call(teams, observed_at: observed_at)

      expect(input.teams).not_to be_empty
      team = input.teams.first
      expect(team.name).to be_present
      expect(team.provider_identities.first).to have_attributes(
        provider: "espn",
        namespace: "team"
      )
    end

    context "when mapping representative NFL catalog nicknames" do
      let(:teams) { acquire_teams(fixture_root.join("teams.json").read) }

      subject(:by_display_name) do
        described_class.call(teams, observed_at: observed_at).teams.index_by(&:name)
      end

      it "maps Commanders, Ravens, and 49ers nicknames from provider fields" do
        expect(by_display_name["Washington Commanders"].nickname).to eq("Commanders")
        expect(by_display_name["Baltimore Ravens"].nickname).to eq("Ravens")
        expect(by_display_name["San Francisco 49ers"].nickname).to eq("49ers")
      end
    end
  end

  it "does not reference ApplicationRecord from transformer sources" do
    Dir[Jumbotron::Engine.root.join("app/adapters/jumbotron/adapters/espn/nfl_helpers/**/*.rb")].each do |path|
      source = File.read(path)
      expect(source).not_to match(/ApplicationRecord|ActiveRecord|\.create!|\.save!/)
    end
  end
end
