# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Public::AssemblePublicGame do
  let(:home) { create(:jumbotron_team, name: "Buffalo Bills", nickname: "Bills") }
  let(:away) { create(:jumbotron_team, name: "Miami Dolphins", nickname: "Dolphins") }
  let(:game) { create(:jumbotron_game, lifecycle: "scheduled") }

  before do
    create(:jumbotron_game_participant, game: game, team: home, role: "home")
    create(:jumbotron_game_participant, game: game, team: away, role: "away")
  end

  describe ".call" do
    context "when the game has no progress columns" do
      subject(:result) { described_class.call(game: game) }

      it "returns nil progress" do
        expect(result).to be_success
        expect(result.data[:public_game].progress).to be_nil
        expect(result.data[:public_game]).to be_a(Jumbotron::Public::Game)
        expect(result.data[:public_game]).not_to be_a(ActiveRecord::Base)
      end

      it "includes immutable semantic Public::Team.key alongside id, name, and nickname" do
        public_game = result.data[:public_game]
        teams = public_game.participants.map(&:team)

        expect(Jumbotron::Public::Team.members).to eq(%i[id name nickname key abbreviation])
        expect(teams).to contain_exactly(
          have_attributes(
            id: home.id,
            name: "Buffalo Bills",
            nickname: "Bills",
            key: "buffalo-bills",
            abbreviation: nil
          ),
          have_attributes(
            id: away.id,
            name: "Miami Dolphins",
            nickname: "Dolphins",
            key: "miami-dolphins",
            abbreviation: nil
          )
        )
        expect(teams.map(&:key)).not_to include(home.id.to_s, away.id.to_s)
        expect(teams.map(&:key)).to all(match(Jumbotron::TeamKey::FORMAT))
      end
    end

    context "when the game has active progress with a clock" do
      before do
        game.update!(
          lifecycle: "in_progress",
          progress_state: "active",
          progress_segment_kind: "quarter",
          progress_segment_number: 3,
          progress_clock_mode: "remaining",
          progress_clock_seconds: 261,
          progress_clock_display: "4:21"
        )
      end

      subject(:result) { described_class.call(game: game.reload) }

      it "materializes nested public progress" do
        expect(result.data[:public_game].progress).to be_a(Jumbotron::Public::GameProgress)
        expect(result.data[:public_game].progress.state).to eq("active")
        expect(result.data[:public_game].progress.segment).to have_attributes(kind: "quarter", number: 3)
        expect(result.data[:public_game].progress.clock).to have_attributes(
          mode: "remaining",
          seconds: 261,
          display: "4:21"
        )
      end
    end

    context "when the game is in intermission" do
      before do
        game.update!(
          lifecycle: "in_progress",
          progress_state: "intermission",
          progress_segment_kind: "quarter",
          progress_segment_number: 2
        )
      end

      subject(:result) { described_class.call(game: game.reload) }

      it "returns progress with a nil clock" do
        expect(result.data[:public_game].progress.state).to eq("intermission")
        expect(result.data[:public_game].progress.segment).to have_attributes(kind: "quarter", number: 2)
        expect(result.data[:public_game].progress.clock).to be_nil
      end
    end

    context "when a scheduled game has entering record and venue address" do
      let(:venue) { create(:jumbotron_venue, name: "Highmark Stadium", city: "Orchard Park", region: "NY") }
      let(:game) { create(:jumbotron_game, lifecycle: "scheduled", venue: venue) }

      before do
        home.update!(abbreviation: "BUF")
        Jumbotron::GameParticipant.find_by!(game: game, team: home).update!(
          record_summary_entering: "8-3"
        )
      end

      subject(:result) { described_class.call(game: game.reload) }

      it "projects entering record and venue city/region" do
        public_game = result.data[:public_game]
        home_participant = public_game.participants.find { |p| p.role == "home" }

        expect(home_participant.record).to eq("8-3")
        expect(home_participant.team.abbreviation).to eq("BUF")
        expect(public_game.venue).to have_attributes(city: "Orchard Park", region: "NY")
      end
    end

    context "when a completed game has no post-game observation" do
      let(:game) { create(:jumbotron_game, lifecycle: "completed") }

      before do
        Jumbotron::GameParticipant.find_by!(game: game, team: home).update!(
          record_summary_entering: "8-3"
        )
      end

      subject(:result) { described_class.call(game: game.reload) }

      it "omits record rather than falling back to entering" do
        home_participant = result.data[:public_game].participants.find { |p| p.role == "home" }
        expect(home_participant.record).to be_nil
      end
    end

    context "when a completed game has a post-game observation" do
      let(:game) { create(:jumbotron_game, lifecycle: "completed") }

      before do
        Jumbotron::GameParticipant.find_by!(game: game, team: home).update!(
          record_summary_entering: "8-3",
          record_summary_post_game: "9-3"
        )
      end

      subject(:result) { described_class.call(game: game.reload) }

      it "projects the post-game record" do
        home_participant = result.data[:public_game].participants.find { |p| p.role == "home" }
        expect(home_participant.record).to eq("9-3")
      end
    end
  end
end
