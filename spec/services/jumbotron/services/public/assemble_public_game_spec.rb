# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Public::AssemblePublicGame do
  let(:game) { create(:jumbotron_game, lifecycle: "scheduled") }

  describe ".call" do
    context "when the game has no progress columns" do
      subject(:result) { described_class.call(game: game) }

      it "returns nil progress" do
        expect(result).to be_success
        expect(result.data[:public_game].progress).to be_nil
        expect(result.data[:public_game]).to be_a(Jumbotron::Public::Game)
        expect(result.data[:public_game]).not_to be_a(ActiveRecord::Base)
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
  end
end
