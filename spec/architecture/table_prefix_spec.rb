# frozen_string_literal: true

RSpec.describe "Jumbotron table prefix" do
  let(:jumbotron_column_names) do
    [
      Jumbotron::Sport,
      Jumbotron::League,
      Jumbotron::Season,
      Jumbotron::SeasonPhase,
      Jumbotron::ScheduleGroup,
      Jumbotron::ProviderIdentity,
      Jumbotron::Team,
      Jumbotron::Venue,
      Jumbotron::Game,
      Jumbotron::GameParticipant,
      Jumbotron::Bookmaker
    ].flat_map(&:column_names)
  end

  it "prefixes Sport" do
    expect(Jumbotron::Sport.table_name).to eq("jumbotron_sports")
  end

  it "prefixes League" do
    expect(Jumbotron::League.table_name).to eq("jumbotron_leagues")
  end

  it "prefixes Season" do
    expect(Jumbotron::Season.table_name).to eq("jumbotron_seasons")
  end

  it "prefixes SeasonPhase" do
    expect(Jumbotron::SeasonPhase.table_name).to eq("jumbotron_season_phases")
  end

  it "prefixes ScheduleGroup" do
    expect(Jumbotron::ScheduleGroup.table_name).to eq("jumbotron_schedule_groups")
  end

  it "prefixes ProviderIdentity" do
    expect(Jumbotron::ProviderIdentity.table_name).to eq("jumbotron_provider_identities")
  end

  it "prefixes Team" do
    expect(Jumbotron::Team.table_name).to eq("jumbotron_teams")
  end

  it "prefixes Venue" do
    expect(Jumbotron::Venue.table_name).to eq("jumbotron_venues")
  end

  it "prefixes Game" do
    expect(Jumbotron::Game.table_name).to eq("jumbotron_games")
  end

  it "prefixes GameParticipant" do
    expect(Jumbotron::GameParticipant.table_name).to eq("jumbotron_game_participants")
  end

  it "prefixes Bookmaker" do
    expect(Jumbotron::Bookmaker.table_name).to eq("jumbotron_bookmakers")
  end

  it "does not prefix the dummy host ApplicationRecord" do
    expect(ApplicationRecord.table_name_prefix).to eq("")
  end

  it "does not define home_team_id on Game" do
    expect(Jumbotron::Game.column_names).not_to include("home_team_id")
  end

  it "does not define away_team_id on Game" do
    expect(Jumbotron::Game.column_names).not_to include("away_team_id")
  end

  it "does not expose espn_id on Jumbotron tables" do
    expect(jumbotron_column_names).not_to include("espn_id")
  end
end
