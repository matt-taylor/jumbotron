# frozen_string_literal: true

RSpec.describe Jumbotron::ScheduleGroup do
  it "persists a numbered week grouping under a season phase" do
    group = create(:jumbotron_schedule_group, kind: "week", number: 4, name: "Week 4")

    expect(group).to be_persisted
    expect(group.kind).to eq("week")
    expect(group.number).to eq(4)
    expect(group.season_phase).to be_present
  end

  it "persists a soccer matchday without Game sport-specific columns" do
    group = create(
      :jumbotron_schedule_group,
      kind: "matchday",
      number: 12,
      name: "Matchweek 12"
    )

    expect(group.kind).to eq("matchday")
    expect(group.number).to eq(12)
    expect(Jumbotron::Game.column_names).not_to include("matchweek")
  end

  it "persists a named knockout round with no number" do
    group = create(
      :jumbotron_schedule_group,
      kind: "knockout_round",
      number: nil,
      name: "Quarterfinal"
    )

    expect(group.number).to be_nil
    expect(group.name).to eq("Quarterfinal")
  end

  it "rejects a season phase from another season" do
    group = build(
      :jumbotron_schedule_group,
      season: create(:jumbotron_season),
      season_phase: create(:jumbotron_season_phase)
    )

    expect(group).not_to be_valid
  end

  it "enforces identity uniqueness" do
    first = create(:jumbotron_schedule_group, kind: "week", number: 1, name: "Week 1")

    expect do
      create(
        :jumbotron_schedule_group,
        season: first.season,
        season_phase: first.season_phase,
        kind: "week",
        number: 99,
        name: "Week 1"
      )
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
