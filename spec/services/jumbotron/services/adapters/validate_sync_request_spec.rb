# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::ValidateSyncRequest do
  let(:league) { create(:jumbotron_league) }

  before { Jumbotron::Adapters::Espn::Nfl.register! unless Jumbotron::Adapters::Espn::Nfl.registered? }

  it "returns the league for a registered adapter and known endpoint" do
    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :scoreboard,
      league_id: league.id
    )

    expect(result).to be_success
    expect(result.data[:league]).to eq(league)
  end

  it "fails when the adapter is not registered" do
    orphan = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecValidateOrphan"
      end

      provider :espn
      sport "football"
      league "ghost"
      endpoint :teams,
               resource: Jumbotron::Providers::Espn::Resources::Teams,
               transformer: Jumbotron::Adapters::Espn::NflHelpers::Teams
    end
    stub_const("Jumbotron::Adapters::SpecValidateOrphan", orphan)

    result = described_class.call(adapter: orphan, endpoint: :teams, league_id: league.id)
    expect(result).to be_failure
    expect(result.errors.first.code).to eq("adapter_not_registered")
  end

  it "fails for an unknown endpoint" do
    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :odds,
      league_id: league.id
    )
    expect(result).to be_failure
    expect(result.errors.first.code).to eq("unknown_endpoint")
  end

  it "fails when the league is missing" do
    result = described_class.call(
      adapter: Jumbotron::Adapters::Espn::Nfl,
      endpoint: :teams,
      league_id: 0
    )
    expect(result).to be_failure
    expect(result.errors.first.code).to eq("league_not_found")
  end
end
