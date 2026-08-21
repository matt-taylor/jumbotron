# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Registry do
  after do
    described_class.reset!
    Jumbotron::Adapters::Espn::Nfl.register!
  end

  before { described_class.reset! }

  it "registers a class reference and reports registered?" do
    adapter = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecAlpha"
      end
    end
    stub_const("Jumbotron::Adapters::SpecAlpha", adapter)

    Jumbotron::Adapters::SpecAlpha.register!

    expect(Jumbotron::Adapters::SpecAlpha.registered?).to be(true)
    expect(described_class.registered).to include(Jumbotron::Adapters::SpecAlpha)
  end

  it "treats duplicate register! of the same class as idempotent" do
    adapter = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecBeta"
      end
    end
    stub_const("Jumbotron::Adapters::SpecBeta", adapter)

    Jumbotron::Adapters::SpecBeta.register!
    Jumbotron::Adapters::SpecBeta.register!

    expect(described_class.registered.count { |c| c == Jumbotron::Adapters::SpecBeta }).to eq(1)
  end

  it "raises when two different classes share the same registry key" do
    first = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecConflictA"
      end

      provider :espn
      sport "football"
      league "conflict-league"
    end
    second = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecConflictB"
      end

      provider :espn
      sport "football"
      league "conflict-league"
    end
    stub_const("Jumbotron::Adapters::SpecConflictA", first)
    stub_const("Jumbotron::Adapters::SpecConflictB", second)

    first.register!
    second.register!

    expect { first.operation(:missing) }.to raise_error(Jumbotron::Adapters::RegistrationError)
  end

  it "does not treat an unregistered subclass as registered" do
    orphan = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecOrphan"
      end
    end
    stub_const("Jumbotron::Adapters::SpecOrphan", orphan)

    expect(orphan.registered?).to be(false)
  end

  it "allows top-of-class register! before provider/sport/league are declared" do
    late = Class.new(Jumbotron::Adapters::Base) do
      def self.name
        "Jumbotron::Adapters::SpecLate"
      end

      register!
      provider :espn
      sport "football"
      league "late"
    end
    stub_const("Jumbotron::Adapters::SpecLate", late)

    expect(late.registered?).to be(true)
    expect(late.registry_key).to eq(%w[espn football late])
  end

  it "finds a registered adapter by adapter_id" do
    Jumbotron::Adapters::Espn::Nfl.register!

    expect(described_class.find("espn_nfl")).to eq(Jumbotron::Adapters::Espn::Nfl)
    expect(described_class.find("missing")).to be_nil
  end

  it "ensure_loaded! constantizes on-disk adapters into the registry" do
    expect(described_class.find("espn_nfl")).to be_nil

    described_class.ensure_loaded!

    expect(described_class.find("espn_nfl")).to eq(Jumbotron::Adapters::Espn::Nfl)
  end
end
