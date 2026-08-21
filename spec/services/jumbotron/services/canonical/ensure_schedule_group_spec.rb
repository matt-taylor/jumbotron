# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::EnsureScheduleGroup do
  let(:season) { create(:jumbotron_season, name: "2025") }
  let(:phase) { create(:jumbotron_season_phase, season: season, name: "regular_season") }

  it "creates a generic grouping from adapter input" do
    result = described_class.call(
      season: season,
      season_phase: phase,
      schedule_group_input: Jumbotron::Canonical::ScheduleGroupInput.new(
        kind: "week",
        number: 4,
        name: "Week 4"
      )
    )

    expect(result).to be_success
    group = result.data[:schedule_group]
    expect(group).to have_attributes(kind: "week", number: 4, name: "Week 4")
    expect(group.season).to eq(season)
  end

  it "returns nil when input is absent" do
    result = described_class.call(season: season, season_phase: phase, schedule_group_input: nil)

    expect(result).to be_success
    expect(result.data[:schedule_group]).to be_nil
  end

  it "is idempotent for the same identity" do
    input = Jumbotron::Canonical::ScheduleGroupInput.new(kind: "week", number: 1, name: "Week 1")
    first = described_class.call(season: season, season_phase: phase, schedule_group_input: input)
    second = described_class.call(season: season, season_phase: phase, schedule_group_input: input)

    expect(second.data[:schedule_group].id).to eq(first.data[:schedule_group].id)
  end
end
