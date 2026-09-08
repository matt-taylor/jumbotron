# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Sandbox::NflHelpers::Scoreboard do
  let(:observed_at) { Time.utc(2026, 9, 8, 16, 0, 0) }
  let(:progress) do
    Jumbotron::Canonical::GameProgress.new(
      state: "active",
      segment: Jumbotron::Canonical::GameSegment.new(kind: "quarter", number: 3),
      clock: Jumbotron::Canonical::GameClock.new(mode: "remaining", seconds: 600, display: "10:00")
    )
  end
  let(:observation) do
    Jumbotron::Adapters::Sandbox::NflHelpers::SyntheticObservation::Observation.new(
      lifecycle: "in_progress",
      progress: progress,
      home_score: 17,
      away_score: 10,
      home_result: nil,
      away_result: nil
    )
  end
  let(:payload) do
    {
      game_id: 123,
      event_id: "sandbox-event-1",
      competition_id: "sandbox-competition-1",
      scheduled_at: "2026-09-10T17:15:00Z",
      season_year: 2026,
      season_phase_key: "regular_season",
      week_number: 1,
      home: {
        provider_id: "10",
        name: "Home Team",
        nickname: "Homes",
        abbreviation: "HOM"
      },
      away: {
        provider_id: "20",
        name: "Away Team",
        nickname: "Aways",
        abbreviation: "AWY"
      }
    }
  end

  before do
    allow(Jumbotron::Services::Sandbox::ResolveGameObservation).to receive(:call).and_return(
      CommandTower::Services::ServiceResult.success(
        data: {
          observation: observation,
          scheduled_at: Time.utc(2026, 9, 11, 17, 15, 0)
        }
      )
    )
  end

  subject(:input) { described_class.call(payload, observed_at: observed_at) }

  it "builds one canonical game with the resolved observation" do
    expect(input).to be_a(Jumbotron::Canonical::SyncInput)
    expect(input.observed_at).to eq(observed_at)
    expect(input.games.size).to eq(1)
    expect(input.games.first).to have_attributes(
      lifecycle: "in_progress",
      scheduled_at: Time.utc(2026, 9, 11, 17, 15, 0),
      season_year: 2026,
      season_phase_key: "regular_season",
      progress: progress
    )
  end

  it "uses the reloaded canonical kickoff instead of stale acquisition data" do
    expect(input.games.first.scheduled_at).not_to eq(Time.iso8601(payload.fetch(:scheduled_at)))
  end

  it "maps the synthetic scores into ordinary participants" do
    expect(input.games.first.participants.map { |participant| [participant.role, participant.score] })
      .to contain_exactly(["home", 17], ["away", 10])
  end

  it "uses sandbox identities for the game and ESPN identities for shared teams" do
    expect(input.games.first.provider_identities.map(&:provider)).to contain_exactly("sandbox", "sandbox")
    expect(input.games.first.provider_identities.map(&:namespace)).to contain_exactly("event", "competition")
    expect(input.games.first.participants.map(&:role)).to contain_exactly("home", "away")
    expect(input.games.first.participants.flat_map(&:provider_identities).map(&:provider)).to contain_exactly(
      "espn", "espn"
    )
  end

  context "when required observation data is absent" do
    let(:payload) { { event_id: "sandbox-event-1" } }

    it "raises a transform error" do
      expect { input }.to raise_error(
        Jumbotron::Adapters::TransformError,
        /invalid sandbox scoreboard observation/
      )
    end
  end

  context "when observation resolution fails" do
    before do
      allow(Jumbotron::Services::Sandbox::ResolveGameObservation).to receive(:call).and_return(
        CommandTower::Services::ServiceResult.failure(
          errors: [Jumbotron::Errors::Sandbox::OutcomeLineUnavailableError.new]
        )
      )
    end

    it "raises a transform error" do
      expect { input }.to raise_error(
        Jumbotron::Adapters::TransformError,
        /requires current home spread and over total lines/
      )
    end
  end
end
