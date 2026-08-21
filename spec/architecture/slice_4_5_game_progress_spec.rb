# frozen_string_literal: true

RSpec.describe "Slice 4.5 sport-agnostic Game Progress" do
  let(:root) { Jumbotron::Engine.root }
  let(:generic_paths) do
    %w[
      app/models/jumbotron/canonical.rb
      app/models/jumbotron/public.rb
      app/models/jumbotron/game.rb
      app/services/jumbotron/services/canonical/upsert_game.rb
      app/services/jumbotron/services/public/assemble_public_game.rb
      db/migrate/20260820000001_add_progress_to_jumbotron_games.rb
    ]
  end
  let(:generic_source) { generic_paths.map { |path| File.read(root.join(path)) }.join("\n") }
  let(:canonical_public_service_source) do
    Dir[root.join("app/services/jumbotron/services/{canonical,public}/**/*.rb")]
      .map { |path| File.read(path) }
      .join("\n")
  end
  let(:progress_adapter_source) do
    File.read(root.join("app/adapters/jumbotron/adapters/espn/nfl_helpers/progress.rb"))
  end

  it "does not add NFL-specific column names to Game" do
    expect(Jumbotron::Game.column_names).not_to include("quarter", "time_remaining", "display_clock")
  end

  it "persists generic progress columns" do
    expect(Jumbotron::Game.column_names).to include(
      "progress_state",
      "progress_segment_kind",
      "progress_segment_number",
      "progress_clock_mode",
      "progress_clock_seconds",
      "progress_clock_display"
    )
  end

  it "does not name canonical or public fields after ESPN displayClock" do
    expect(generic_source).not_to include("displayClock")
    expect(generic_source).not_to include("display_clock")
    expect(Jumbotron::Canonical::GameProgress.members).to eq(%i[state segment clock])
    expect(Jumbotron::Public::GameProgress.members).to eq(%i[state segment clock])
  end

  it "does not use sport-specific progress state tokens in generic layers" do
    expect(generic_source).not_to include("halftime")
    expect(Jumbotron::Game::PROGRESS_STATES).to contain_exactly("active", "intermission")
  end

  it "does not persist ESPN STATUS_* vocabulary on Game progress" do
    expect(generic_source).not_to include("STATUS_")
  end

  it "keeps generic canonical and public services free of sport and league conditionals" do
    expect(canonical_public_service_source).not_to include("if sport ==")
    expect(canonical_public_service_source).not_to include("if league ==")
  end

  it "does not put provider ids on public Game Progress" do
    expect(Jumbotron::Public::GameProgress.members).not_to include(:provider_id)
    expect(Jumbotron::Public::GameSegment.members).not_to include(:provider_id)
    expect(Jumbotron::Public::GameClock.members).not_to include(:provider_id)
  end

  it "does not encode NFL intermission as a half segment in the NFL progress adapter" do
    expect(progress_adapter_source).not_to include('kind: "half"')
    expect(progress_adapter_source).not_to include('"half"')
  end

  it "keeps progress public types off ActiveRecord" do
    expect(Jumbotron::Public::GameProgress.ancestors).not_to include(ActiveRecord::Base)
    expect(Jumbotron::Public::GameSegment.ancestors).not_to include(ActiveRecord::Base)
    expect(Jumbotron::Public::GameClock.ancestors).not_to include(ActiveRecord::Base)
  end
end
