# frozen_string_literal: true

RSpec.describe "Jumbotron engine packaging" do
  subject(:spec) { Gem::Specification.load(gemspec_path.to_s) }

  let(:gemspec_path) { Jumbotron::Engine.root.join("jumbotron.gemspec") }
  let(:rails_dep) { spec.dependencies.find { |dependency| dependency.name == "rails" } }
  let(:command_tower_dep) { spec.dependencies.find { |dependency| dependency.name == "command_tower" } }
  let(:pick_em_dep) { spec.dependencies.find { |dependency| dependency.name == "pick_em" } }

  it "is named jumbotron" do
    expect(spec.name).to eq("jumbotron")
  end

  it "declares a Rails lower bound of 7.0" do
    expect(rails_dep.requirement).to be_satisfied_by(Gem::Version.new("7.0.0"))
  end

  it "accepts Rails 8.x" do
    expect(rails_dep.requirement).to be_satisfied_by(Gem::Version.new("8.9.9"))
  end

  it "rejects Rails 9.0" do
    expect(rails_dep.requirement).not_to be_satisfied_by(Gem::Version.new("9.0.0"))
  end

  it "declares a command_tower dependency" do
    expect(command_tower_dep).not_to be_nil
  end

  it "does not declare a pick_em dependency" do
    expect(pick_em_dep).to be_nil
  end

  it "isolates the Jumbotron namespace" do
    expect(Jumbotron::Engine.isolated?).to be(true)
  end

  it "uses Jumbotron as the railtie namespace" do
    expect(Jumbotron::Engine.railtie_namespace).to eq(Jumbotron)
  end

  it "does not define SportsEngine" do
    expect(defined?(SportsEngine)).to be_nil
  end

  it "packages the catalog migration" do
    expect(spec.files).to include(
      a_string_matching(%r{\Adb/migrate/\d+_create_jumbotron_foundational_catalog\.rb\z})
    )
  end

  it "packages the game-graph migration" do
    expect(spec.files).to include(
      a_string_matching(%r{\Adb/migrate/\d+_create_jumbotron_game_graph\.rb\z})
    )
  end
end
