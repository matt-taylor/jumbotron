# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Sandbox::Nfl do
  let(:adapter) { described_class }
  let(:policy_ids) do
    %i[
      far_future near_future upcoming live interrupted post_final_record
      far_future_lines near_future_lines upcoming_lines in_progress_lines interrupted_lines
    ]
  end

  it "declares isolated sandbox identity" do
    expect(adapter.adapter_id).to eq("sandbox_nfl")
    expect(adapter.provider).to eq("sandbox")
    expect(adapter.sport).to eq("football")
    expect(adapter.league).to eq("nfl-sandbox")
    expect(adapter.registry_key).to eq(%w[sandbox football nfl-sandbox])
  end

  it "declares game and line policies without boot discovery" do
    expect(adapter.policy_ids).to match_array(policy_ids)
    expect(adapter.discovery_ids).to be_empty
    expect(adapter.policy(:live).type).to eq(:live_game_update)
    expect(adapter.policy(:upcoming_lines).type).to eq(:future_line_update)
    expect(adapter.policy(:live).cadence.interval_seconds).to eq(30)
  end

  it "uses the in-process sandbox scoreboard operation" do
    expect(adapter.operation(:scoreboard).resource).to eq(
      Jumbotron::Providers::Sandbox::Resources::Scoreboard
    )
    expect(adapter.operation(:scoreboard).transformer).to eq(
      Jumbotron::Adapters::Sandbox::NflHelpers::Scoreboard
    )
  end
end
