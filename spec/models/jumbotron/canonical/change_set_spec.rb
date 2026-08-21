# frozen_string_literal: true

RSpec.describe Jumbotron::Canonical::ChangeSet do
  it "records material changes and supports iteration/size" do
    set = described_class.new
    team = build(:jumbotron_team)

    set.record(subject: team, attribute: :name, previous: "A", new_value: "B")
    set.record(subject: team, attribute: :name, previous: "B", new_value: "B")

    expect(set).to be_any
    expect(set.size).to eq(1)
    expect(set.map(&:attribute)).to eq(["name"])
  end

  it "is empty when nothing material is recorded" do
    set = described_class.new
    expect(set).not_to be_any
    expect(set.size).to eq(0)
  end
end
