# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Espn::NflHelpers::Scoreboard do
  describe ".call" do
    let(:observed_at) { Time.utc(2026, 9, 7, 12, 0, 0) }
    let(:venue) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Venue::Result,
        id: "1",
        full_name: "Lincoln Financial Field",
        address: instance_double(
          Jumbotron::Deserializers::Clients::Espn::VenueAddress::Result,
          city: "Philadelphia",
          state: "PA"
        )
      )
    end
    let(:team) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Team::Result,
        id: "21",
        display_name: "Philadelphia Eagles",
        name: "Eagles",
        abbreviation: "PHI",
        nickname: nil,
        short_display_name: "Eagles"
      )
    end
    let(:total_record) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::CompetitorRecord::Result,
        type: "total",
        summary: "0-0"
      )
    end
    let(:competitor) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Competitor::Result,
        team: team,
        home_away: "home",
        score: nil,
        winner: nil,
        records: [total_record]
      )
    end
    let(:away_team) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Team::Result,
        id: "6",
        display_name: "Dallas Cowboys",
        name: "Cowboys",
        abbreviation: "DAL",
        nickname: nil,
        short_display_name: "Cowboys"
      )
    end
    let(:away_competitor) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Competitor::Result,
        team: away_team,
        home_away: "away",
        score: nil,
        winner: nil,
        records: [total_record]
      )
    end
    let(:status) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Status::Result,
        type_name: "STATUS_SCHEDULED"
      )
    end
    let(:season) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Season::Result,
        year: 2026,
        type: 2
      )
    end
    let(:competition) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Competition::Result,
        id: "401",
        date: "2026-09-07T17:00Z",
        start_date: "2026-09-07T17:00Z",
        neutral_site: false,
        status: status,
        venue: venue,
        competitors: [competitor, away_competitor]
      )
    end
    let(:event) do
      instance_double(
        Jumbotron::Deserializers::Clients::Espn::Event::Result,
        id: "401",
        date: "2026-09-07T17:00Z",
        status: status,
        season: season,
        week: instance_double(Jumbotron::Deserializers::Clients::Espn::Week::Result, number: 1),
        competitions: [competition]
      )
    end
    let(:board) do
      instance_double(Jumbotron::Deserializers::Clients::Espn::Scoreboard::Get::Result, events: [event])
    end

    before do
      allow(Jumbotron::Adapters::Espn::NflHelpers::Lifecycle).to receive(:call)
        .with("STATUS_SCHEDULED").and_return("scheduled")
      allow(Jumbotron::Adapters::Espn::NflHelpers::SeasonPhase).to receive(:call)
        .with(2).and_return("regular_season")
      allow(Jumbotron::Adapters::Espn::NflHelpers::Progress).to receive(:call)
        .and_return(nil)
      allow(Jumbotron::Adapters::Espn::NflHelpers::TeamNickname).to receive(:resolve)
        .and_return("Eagles", "Cowboys")
    end

    subject(:sync) { described_class.call(board, observed_at: observed_at) }

    it "projects venue city/region, team abbreviation, and total record summary" do
      game = sync.games.first
      home = game.participants.find { |p| p.role == "home" }

      expect(game.venue.city).to eq("Philadelphia")
      expect(game.venue.region).to eq("PA")
      expect(home.team_abbreviation).to eq("PHI")
      expect(home.record_summary).to eq("0-0")
    end
  end
end
