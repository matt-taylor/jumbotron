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

  it "temporarily rejects json 3 until Rails splat-decodes" do
    json_dep = spec.dependencies.find { |dependency| dependency.name == "json" }
    expect(json_dep).not_to be_nil
    expect(json_dep.requirement).to be_satisfied_by(Gem::Version.new("2.21.2"))
    expect(json_dep.requirement).not_to be_satisfied_by(Gem::Version.new("3.0.0"))
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

  it "packages the sandbox game-plan migration" do
    expect(spec.files).to include(
      a_string_matching(%r{\Adb/migrate/\d+_create_jumbotron_sandbox_game_plans\.rb\z})
    )
  end

  it "packages the sandbox projection migration" do
    expect(spec.files).to include(
      a_string_matching(%r{\Adb/migrate/\d+_create_jumbotron_sandbox_projections\.rb\z})
    )
  end

  it "packages the host Testing API, testing docs, and factories" do
    expect(spec.files).to include("lib/jumbotron/testing.rb")
    expect(spec.files).to include("docs/testing.md")
    expect(spec.files).to include("spec/factories/jumbotron/game.rb")
  end
end
