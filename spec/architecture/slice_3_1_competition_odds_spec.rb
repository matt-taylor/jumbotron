# frozen_string_literal: true

RSpec.describe "Slice 3.1 competition odds architecture" do
  let(:root) { Jumbotron::Engine.root }

  def sources_under(*globs)
    globs.flat_map { |glob| Dir[root.join(glob)] }.map { |path| File.read(path) }.join("\n")
  end

  it "keeps CompetitionOdds as a provider-wide ESPN endpoint" do
    expect(Jumbotron::Clients::Espn::CompetitionOdds::Get).to be < CommandTower::Clients::EndpointBase
    expect(defined?(Jumbotron::Clients::Espn::NflOdds)).to be_nil
    expect(defined?(Jumbotron::Clients::OddsApi)).to be_nil
    expect(defined?(Jumbotron::Clients::DraftKings)).to be_nil
  end

  it "does not hardcode a sport or league in the generic endpoint or serializer" do
    files = Dir[root.join("app/clients/jumbotron/clients/espn/competition_odds/*.rb")] +
            Dir[root.join("app/serializers/jumbotron/serializers/clients/espn/competition_odds/*.rb")] +
            Dir[root.join("app/providers/jumbotron/providers/espn/resources/competition_odds.rb")]

    files.each do |path|
      source = File.read(path)
      expect(source).not_to match(/\bfootball\b/)
      expect(source).not_to match(/\bnfl\b/i)
    end
  end

  it "does not persist canonical Lines or Bookmakers from provider code" do
    provider_sources = sources_under(
      "app/clients/jumbotron/clients/espn/competition_odds/**/*.rb",
      "app/serializers/jumbotron/serializers/clients/espn/competition_odds/**/*.rb",
      "app/deserializers/jumbotron/deserializers/clients/espn/competition_odds/**/*.rb",
      "app/providers/jumbotron/providers/espn/resources/competition_odds.rb"
    )

    forbidden = [
      "ApplicationRecord", ".create!", ".update!", "Game.", "Bookmaker.",
      "ProviderIdentity.", "LineObservation", "Consensus", "OddsApi", "the-odds-api"
    ]
    forbidden.each do |token|
      expect(provider_sources).not_to include(token)
    end
    expect(Dir[root.join("app/jobs/**/*odds*")]).to be_empty
    expect(Dir[root.join("app/workflows/**/*odds*")]).to be_empty
  end

  it "does not introduce The Odds API or direct sportsbook clients" do
    app_sources = Dir[root.join("app/**/*.rb")].map { |path| File.read(path) }.join("\n")

    expect(app_sources).not_to include("the-odds-api.com")
    expect(app_sources).not_to include("OddsApi::")
    expect(app_sources).not_to include("api.draftkings")
    expect(app_sources).not_to include("bet365")
  end
end
