# frozen_string_literal: true

RSpec.describe Jumbotron do
  it "exposes a version" do
    expect(described_class::VERSION).to eq("0.1.4")
  end

  it "loads an Engine" do
    expect(described_class::Engine).to be < Rails::Engine
  end

  it "isolates the Engine namespace" do
    expect(described_class::Engine.isolated?).to be(true)
  end

  it "inherits ApplicationRecord from ActiveRecord::Base" do
    expect(described_class::ApplicationRecord.superclass).to eq(ActiveRecord::Base)
  end

  it "marks ApplicationRecord as abstract" do
    expect(described_class::ApplicationRecord.abstract_class?).to be(true)
  end
end
