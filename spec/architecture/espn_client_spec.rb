# frozen_string_literal: true

RSpec.describe "ESPN client architecture" do
  it "keeps ESPN acquisition under Clients / Serializers / Deserializers namespaces" do
    root = Jumbotron::Engine.root
    client_files = Dir[root.join("app/clients/**/*.rb")]
    serializer_files = Dir[root.join("app/serializers/**/*.rb")]
    deserializer_files = Dir[root.join("app/deserializers/**/*.rb")]

    expect(client_files).not_to be_empty
    expect(serializer_files).not_to be_empty
    expect(deserializer_files).not_to be_empty

    expect(defined?(Jumbotron::Clients::Espn)).to eq("constant")
    expect(Jumbotron::Clients::Espn).to be < CommandTower::Clients::ClientBase
    expect(Jumbotron::Clients::Espn::Scoreboard::Get).to be < CommandTower::Clients::EndpointBase
    expect(Jumbotron::Clients::Espn::Teams::Get).to be < CommandTower::Clients::EndpointBase
    expect(Jumbotron::Clients::Espn::CompetitionOdds::Get).to be < CommandTower::Clients::EndpointBase
  end

  it "does not define sport-nested ESPN client namespaces" do
    expect(defined?(Jumbotron::Clients::Espn::Nfl)).to be_nil
  end
end
