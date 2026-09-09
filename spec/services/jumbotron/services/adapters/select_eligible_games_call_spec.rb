# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::SelectEligibleGames, ".call" do
  let(:now) { Time.utc(2026, 9, 8, 16, 0, 0) }
  let(:sport) { create(:jumbotron_sport, name: "football") }
  let(:source_league) { create(:jumbotron_league, sport: sport, name: "nfl") }
  let(:sandbox_league) { create(:jumbotron_league, sport: sport, name: "nfl-sandbox") }
  let(:source_game) do
    create(
      :jumbotron_game,
      league: source_league,
      season: create(:jumbotron_season, league: source_league, name: "2026"),
      scheduled_at: now + 1.week
    )
  end
  let(:sandbox_game) do
    create(
      :jumbotron_game,
      league: sandbox_league,
      season: create(:jumbotron_season, league: sandbox_league, name: "2026"),
      scheduled_at: now + 1.week
    )
  end

  before do
    source_game
    sandbox_game
    Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered?
    Jumbotron::Adapters::Sandbox::Nfl.register! unless Jumbotron::Adapters::Sandbox::Nfl.registered?
  end

  context "with the ESPN adapter" do
    subject(:result) do
      described_class.call(
        adapter: Jumbotron::Adapters::Espn::Nfl,
        policy: Jumbotron::Adapters::Espn::Nfl.policy(:upcoming),
        now: now
      )
    end

    it "selects only live-source games" do
      expect(result).to be_success
      expect(result.data[:games]).to contain_exactly(source_game)
      expect(result.data[:games]).not_to include(sandbox_game)
    end
  end

  context "with the sandbox adapter" do
    subject(:result) do
      described_class.call(
        adapter: Jumbotron::Adapters::Sandbox::Nfl,
        policy: Jumbotron::Adapters::Sandbox::Nfl.policy(:upcoming),
        now: now
      )
    end

    it "selects only sandbox-world games" do
      expect(result).to be_success
      expect(result.data[:games]).to contain_exactly(sandbox_game)
      expect(result.data[:games]).not_to include(source_game)
    end
  end
end
