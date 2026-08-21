# frozen_string_literal: true

RSpec.describe Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::Get do
  def fixture(relative)
    JSON.parse(Jumbotron::Engine.root.join("spec/fixtures/espn", relative).read)
  end

  it "preserves two listed providers independently of display name" do
    result = described_class.call(fixture("nfl/core_odds_in_401874392.json"))

    expect(result.items.size).to eq(2)
    expect(result.items.map { |item| item.listed_provider.id }).to contain_exactly("100", "200")
    expect(result.items.map { |item| item.listed_provider.name }).to include(
      "Draft Kings",
      "Draft Kings - Live Odds"
    )
    expect(result.items.first.listed_provider).to be_a(
      Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::ListedProvider::Result
    )
    expect(result.items.first).not_to be_a(Hash)
  end

  it "deserializes spread, total, and moneyline structures" do
    item = described_class.call(fixture("nfl/core_odds_pre_401873278.json")).items.first

    expect(item.spread).to eq(3.5)
    expect(item.over_under).to eq(40.5)
    expect(item.home_team_odds.money_line).to eq(160.0)
    expect(item.home_team_odds.current.point_spread.american).to eq("+3.5")
    expect(item.home_team_odds.current.spread.american).to eq("-102")
    expect(item.home_team_odds.current.money_line.american).to eq("+160")
    expect(item.home_team_odds.current.spread).to be_a(
      Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::Price::Result
    )
  end

  it "deserializes open, current, and close when ESPN returns them" do
    item = described_class.call(fixture("nfl/core_odds_post_401873272.json")).items.first

    expect(item.home_team_odds.open).to be_a(
      Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::SideQuote::Result
    )
    expect(item.home_team_odds.close.point_spread.american).to eq("-6.5")
    expect(item.home_team_odds.current.point_spread.american).to eq("-6.5")
    expect(item.open).to be_a(Jumbotron::Deserializers::Clients::Espn::CompetitionOdds::MarketWindow::Result)
    expect(item.current.total.american).to eq("37.5")
  end

  it "tolerates missing markets and sparse listed-provider rows" do
    result = described_class.call(fixture("soccer/eng1/core_odds_401879301.json"))
    sparse = result.items.find { |item| item.listed_provider.id == "2000" }
    featured = result.items.find { |item| item.listed_provider.id == "100" }

    expect(result.items.size).to eq(2)
    expect(featured.draw_odds.money_line).to eq(650.0)
    expect(sparse.spread).to be_nil
    expect(sparse.over_under).to be_nil
    expect(sparse.home_team_odds.money_line).to be_nil
    expect(sparse.open).to be_nil
    expect(sparse.close).to be_nil
    expect(sparse.current).to be_nil
  end

  it "deserializes an empty items collection" do
    result = described_class.call(fixture("nfl/core_odds_empty.json"))

    expect(result.items).to eq([])
    expect(result.count).to eq(0)
  end

  it "fails when items is not an array" do
    expect { described_class.call({ "items" => {} }) }.to raise_error(
      CommandTower::Clients::Errors::DeserializationError
    )
  end
end
