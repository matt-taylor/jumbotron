# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Public::ReadScheduleGroups do
  let(:sport) { create(:jumbotron_sport, name: "football") }
  let(:league) { create(:jumbotron_league, sport: sport, name: "nfl") }
  let(:season) { create(:jumbotron_season, league: league, name: "2026") }
  let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }
  let(:request) do
    Jumbotron::Public::ScheduleGroupsRequest.new(
      league_id: nil,
      sport: "football",
      league: "nfl",
      season_id: nil,
      season: "2026",
      season_phase: "regular_season",
      kind: nil
    )
  end

  describe ".call" do
    context "when the phase has an observed group" do
      before do
        create(
          :jumbotron_schedule_group,
          season: season,
          season_phase: phase,
          kind: "week",
          number: 1,
          name: "Week 1"
        )
      end

      subject(:result) { described_class.call(request: request) }

      it "lists groups for the resolved phase" do
        expect(result).to be_success
        expect(result.data[:schedule_groups].completeness).to eq(:incomplete)
        expect(result.data[:schedule_groups].groups.map(&:number)).to eq([1])
      end
    end

    context "when inspecting completeness invariants" do
      before do
        create(
          :jumbotron_schedule_group,
          season: season,
          season_phase: phase,
          kind: "week",
          number: 1,
          name: "Week 1"
        )
      end

      let(:service_source) do
        File.read(
          Jumbotron::Engine.root.join("app/services/jumbotron/services/public/read_schedule_groups.rb")
        )
      end

      subject(:result) { described_class.call(request: request) }

      it "never returns complete completeness" do
        expect(service_source).to include("completeness: :incomplete")
        expect(service_source).not_to match(/completeness:\s*:complete/)
        expect(result.data[:schedule_groups].completeness).to eq(:incomplete)
      end
    end
  end
end
