# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Canonical::UpsertGameParticipant do
  let(:change_set) { Jumbotron::Canonical::ChangeSet.new }
  let(:observed_at) { Time.utc(2026, 9, 7, 18, 0, 0) }
  let(:team) { create(:jumbotron_team, name: "Philadelphia Eagles", nickname: "Eagles") }
  let(:game) { create(:jumbotron_game, lifecycle: lifecycle) }
  let(:lifecycle) { "scheduled" }
  let(:participant_input) do
    Jumbotron::Canonical::ParticipantInput.new(
      provider_identities: [
        Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "team", id: "21")
      ],
      team_name: team.name,
      team_nickname: "Eagles",
      team_abbreviation: "PHI",
      role: "home",
      score: nil,
      result: nil,
      record_summary: record_summary
    )
  end
  let(:record_summary) { "8-3" }

  before do
    create(
      :jumbotron_provider_identity,
      target: team,
      provider: "espn",
      object_namespace: "team",
      provider_id: "21"
    )
  end

  describe ".call" do
    context "when the game is upcoming" do
      subject(:result) do
        described_class.call(
          game: game,
          participant_input: participant_input,
          observed_at: observed_at,
          change_set: change_set
        )
      end

      it "persists entering and current record snapshots" do
        expect(result).to be_success
        gp = result.data[:game_participant]
        expect(gp.record_summary_entering).to eq("8-3")
        expect(gp.record_summary_current).to eq("8-3")
        expect(gp.record_summary_post_game).to be_nil
        expect(team.reload.abbreviation).to eq("PHI")
      end
    end

    context "when the game completes with an advanced ESPN total" do
      let(:lifecycle) { "completed" }
      let(:record_summary) { "9-3" }
      let(:participant_input) do
        Jumbotron::Canonical::ParticipantInput.new(
          provider_identities: [
            Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "team", id: "21")
          ],
          team_name: team.name,
          team_nickname: "Eagles",
          team_abbreviation: "PHI",
          role: "home",
          score: 27,
          result: "win",
          record_summary: record_summary
        )
      end

      before do
        create(
          :jumbotron_game_participant,
          game: game,
          team: team,
          role: "home",
          record_summary_entering: "8-3",
          record_summary_current: "8-3"
        )
      end

      subject(:result) do
        described_class.call(
          game: game,
          participant_input: participant_input,
          observed_at: observed_at,
          change_set: change_set
        )
      end

      it "persists post-game without overwriting entering" do
        expect(result).to be_success
        gp = result.data[:game_participant]
        expect(gp.record_summary_entering).to eq("8-3")
        expect(gp.record_summary_post_game).to eq("9-3")
      end
    end

    context "when the final payload still shows the entering total" do
      let(:lifecycle) { "completed" }
      let(:record_summary) { "8-3" }

      before do
        create(
          :jumbotron_game_participant,
          game: game,
          team: team,
          role: "home",
          record_summary_entering: "8-3",
          record_summary_current: "8-3"
        )
      end

      subject(:result) do
        described_class.call(
          game: game,
          participant_input: Jumbotron::Canonical::ParticipantInput.new(
            provider_identities: [
              Jumbotron::Canonical::ProviderIdentityRef.new(provider: "espn", namespace: "team", id: "21")
            ],
            team_name: team.name,
            role: "home",
            score: 27,
            result: "win",
            record_summary: record_summary
          ),
          observed_at: observed_at,
          change_set: change_set
        )
      end

      it "leaves post-game nil for Strategy B refresh" do
        expect(result).to be_success
        gp = result.data[:game_participant]
        expect(gp.record_summary_entering).to eq("8-3")
        expect(gp.record_summary_post_game).to be_nil
        expect(gp.record_summary_current).to eq("8-3")
      end
    end
  end
end
