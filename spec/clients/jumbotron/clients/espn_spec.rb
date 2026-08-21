# frozen_string_literal: true

RSpec.describe Jumbotron::Clients::Espn do
  after { Jumbotron::Clients.reset_providers! }

  let(:fixture_root) { Jumbotron::Engine.root.join("spec/fixtures/espn/nfl") }
  let(:scoreboard_final_body) { fixture_root.join("scoreboard_2025_w1.json").read }
  let(:scoreboard_scheduled_body) { fixture_root.join("scoreboard_2026_pre.json").read }
  let(:teams_body) { fixture_root.join("teams.json").read }

  describe "scoreboard.get" do
    context "when ESPN returns a final week scoreboard fixture" do
      before { Jumbotron::Clients.seed_provider!(:espn, described_class.new(transport: transport)) }

      let(:transport) do
        Jumbotron::SpecSupport::FakeTransport.new do |_request|
          CommandTower::Clients::Transport::Response.build(
            status: 200,
            body: scoreboard_final_body,
            duration_ms: 1
          )
        end
      end

      subject(:result) do
        Jumbotron::Clients.espn.scoreboard.get(
          sport: "football",
          league: "nfl",
          season_type: 2,
          week: 1,
          dates: 2025
        )
      end

      it "issues a GET to the sport/league scoreboard path" do
        result
        expect(transport.calls.first.method).to eq(:get)
        expect(transport.calls.first.url).to include("football/nfl/scoreboard")
        expect(transport.calls.first.query).to include(
          "seasontype" => 2,
          "week" => 1,
          "dates" => 2025
        )
      end

      it "returns a typed scoreboard result" do
        expect(result).to be_success
        expect(result.output).to be_a(Jumbotron::Deserializers::Clients::Espn::Scoreboard::Get::Result)
      end

      it "deserializes typed events" do
        expect(result.output.events).not_to be_empty
        expect(result.output.events.first).to be_a(Jumbotron::Deserializers::Clients::Espn::Event::Result)
        expect(result.output.events.first.id).to be_a(String)
      end

      it "deserializes competition status and competitors" do
        competition = result.output.events.first.competitions.first
        expect(result.output.events.first.competitions.length).to eq(1)
        expect(competition.status.type_name).to eq("STATUS_FINAL")
        expect(competition.competitors.map(&:home_away)).to contain_exactly("home", "away")
      end

      it "deserializes nested team contracts without raw hashes" do
        team = result.output.events.first.competitions.first.competitors.first.team
        expect(team).to be_a(Jumbotron::Deserializers::Clients::Espn::Team::Result)
        expect(team).not_to be_a(Hash)
      end
    end

    context "when ESPN returns a scheduled scoreboard fixture" do
      before { Jumbotron::Clients.seed_provider!(:espn, described_class.new(transport: transport)) }

      let(:transport) do
        Jumbotron::SpecSupport::FakeTransport.new do |_request|
          CommandTower::Clients::Transport::Response.build(
            status: 200,
            body: scoreboard_scheduled_body,
            duration_ms: 1
          )
        end
      end

      subject(:result) do
        Jumbotron::Clients.espn.scoreboard.get(
          sport: "football",
          league: "nfl",
          season_type: 1,
          week: 2,
          dates: 2026
        )
      end

      it "is successful" do
        expect(result).to be_success
      end

      it "deserializes scheduled statuses" do
        expect(result.output.events.first.competitions.first.status.type_name).to eq("STATUS_SCHEDULED")
      end
    end
  end

  describe "teams.get" do
    context "when ESPN returns the NFL teams fixture" do
      before { Jumbotron::Clients.seed_provider!(:espn, described_class.new(transport: transport)) }

      let(:transport) do
        Jumbotron::SpecSupport::FakeTransport.new do |_request|
          CommandTower::Clients::Transport::Response.build(
            status: 200,
            body: teams_body,
            duration_ms: 1
          )
        end
      end

      subject(:result) do
        Jumbotron::Clients.espn.teams.get(sport: "football", league: "nfl")
      end

      it "issues a GET to the sport/league teams path" do
        result
        expect(transport.calls.first.url).to include("football/nfl/teams")
      end

      it "is successful" do
        expect(result).to be_success
      end

      it "returns typed team contracts" do
        expect(result.output).to be_an(Array)
        expect(result.output.first).to be_a(Jumbotron::Deserializers::Clients::Espn::Team::Result)
        expect(result.output.first.display_name).to be_a(String)
        expect(result.output.size).to eq(32)
      end
    end
  end

  describe "competition_odds.get" do
    before { Jumbotron::Clients.seed_provider!(:espn, described_class.new(transport: transport)) }

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

    subject(:result) do
      Jumbotron::Clients.espn.competition_odds.get(
        sport: "football",
        league: "nfl",
        event_id: "401874392",
        competition_id: "401874392"
      )
    end

    it "issues a GET to the ESPN Core competition odds path" do
      result
      expect(transport.calls.first.method).to eq(:get)
      expect(transport.calls.first.url).to eq(
        "https://sports.core.api.espn.com/v2/sports/football/leagues/nfl/events/401874392/competitions/401874392/odds"
      )
    end

    it "returns a typed collection and does not collapse bookmakers" do
      expect(result).to be_success
      expect(result.output).to be_a(Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::Get::Result)
      expect(result.output.items.size).to eq(2)
      expect(result.output.items.map { |item| item.listed_provider.id }).to contain_exactly("100", "200")
    end

    it "builds a Core path from scalar sport and league" do
      path = Jumbotron::Clients::Espn::CompetitionOdds::Get.declared_path.call(
        Jumbotron::Clients::Espn::CompetitionOdds::GetInput.new(
          sport: "soccer",
          league: "eng.1",
          event_id: "401879301",
          competition_id: "401879301"
        )
      )

      expect(path).to start_with("https://sports.core.api.espn.com/v2/")
      expect(path).to include("sports/soccer/leagues/eng.1/events/401879301/competitions/401879301/odds")
    end
  end
end
