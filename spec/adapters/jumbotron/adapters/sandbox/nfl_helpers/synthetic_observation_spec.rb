# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Sandbox::NflHelpers::SyntheticObservation do
  describe ".call" do
    let(:kickoff) { Time.utc(2026, 9, 13, 17, 0, 0) }
    let(:now) { kickoff }
    let(:plan) { instance_double(Jumbotron::SandboxGamePlan, home_score: 28, away_score: 20) }
    let(:current_progress) { nil }
    let(:current_lifecycle) { "scheduled" }
    let(:current_home_score) { nil }
    let(:current_away_score) { nil }
    let(:progress_for) do
      lambda do |quarter:, seconds:, display:|
        Jumbotron::Canonical::GameProgress.new(
          state: "active",
          segment: Jumbotron::Canonical::GameSegment.new(kind: "quarter", number: quarter),
          clock: Jumbotron::Canonical::GameClock.new(mode: "remaining", seconds: seconds, display: display)
        )
      end
    end
    let(:current) do
      described_class::Current.new(
        lifecycle: current_lifecycle,
        progress: current_progress,
        home_score: current_home_score,
        away_score: current_away_score
      )
    end

    subject(:observation) { described_class.call(now: now, kickoff: kickoff, plan: plan, current: current) }

    context "when observed before kickoff" do
      let(:now) { kickoff - 1.second }

      it "remains scheduled" do
        expect(observation.lifecycle).to eq("scheduled")
      end

      it "does not expose a score" do
        expect(observation.home_score).to be_nil
      end
    end

    context "when observed at kickoff" do
      it "starts the game" do
        expect(observation.lifecycle).to eq("in_progress")
      end

      it "starts quarter one at 15:00" do
        expect(observation.progress).to have_attributes(
          state: "active",
          segment: have_attributes(kind: "quarter", number: 1),
          clock: have_attributes(mode: "remaining", seconds: 900, display: "15:00")
        )
      end

      it "starts at zero" do
        expect(observation).to have_attributes(home_score: 0, away_score: 0)
      end
    end

    context "when observed at the second-quarter boundary" do
      let(:now) { kickoff + described_class::QUARTER_SECONDS }

      it "starts quarter two at 15:00" do
        expect(observation.progress).to have_attributes(
          state: "active",
          segment: have_attributes(number: 2),
          clock: have_attributes(seconds: 900)
        )
      end
    end

    context "when observed at halftime" do
      let(:now) { kickoff + (described_class::QUARTER_SECONDS * 2) }

      it "emits a clockless quarter-two intermission" do
        expect(observation.progress).to have_attributes(
          state: "intermission",
          segment: have_attributes(kind: "quarter", number: 2),
          clock: nil
        )
      end

      it "holds the midpoint score" do
        expect(observation).to have_attributes(home_score: 14, away_score: 10)
      end
    end

    context "when observed at the third-quarter boundary" do
      let(:now) do
        kickoff + (described_class::QUARTER_SECONDS * 2) + described_class::HALFTIME_SECONDS
      end

      it "starts quarter three at 15:00" do
        expect(observation.progress).to have_attributes(
          state: "active",
          segment: have_attributes(number: 3),
          clock: have_attributes(seconds: 900)
        )
      end
    end

    context "when observed at the fourth-quarter boundary" do
      let(:now) do
        kickoff + (described_class::QUARTER_SECONDS * 3) + described_class::HALFTIME_SECONDS
      end

      it "starts quarter four at 15:00" do
        expect(observation.progress).to have_attributes(
          state: "active",
          segment: have_attributes(number: 4),
          clock: have_attributes(seconds: 900)
        )
      end
    end

    context "when observed at the two-hour boundary" do
      let(:now) { kickoff + described_class::TOTAL_SECONDS }

      it "completes at the selected final" do
        expect(observation).to have_attributes(
          lifecycle: "completed",
          progress: nil,
          home_score: 28,
          away_score: 20,
          home_result: "win",
          away_result: "loss"
        )
      end
    end

    context "when observed after the two-hour boundary" do
      let(:now) { kickoff + 3.hours }
      let(:second_observation) { described_class.call(now: now, kickoff: kickoff, plan: plan, current: current) }

      it "keeps the exact selected final" do
        expect(observation).to eq(second_observation)
      end
    end

    context "when observed time moves behind persisted quarter three" do
      let(:now) { kickoff + 10.minutes }
      let(:current_lifecycle) { "in_progress" }
      let(:current_home_score) { 18 }
      let(:current_away_score) { 13 }
      let(:current_progress) do
        progress_for.call(quarter: 3, seconds: 600, display: "10:00")
      end

      it "retains the persisted segment" do
        expect(observation.progress.segment.number).to eq(3)
      end

      it "retains the persisted scores" do
        expect(observation).to have_attributes(home_score: 18, away_score: 13)
      end
    end

    context "when the proposed clock would increase in the same quarter" do
      let(:current_lifecycle) { "in_progress" }
      let(:current_home_score) { 2 }
      let(:current_away_score) { 1 }
      let(:current_progress) do
        progress_for.call(quarter: 1, seconds: 300, display: "5:00")
      end

      it "retains the lower remaining clock" do
        expect(observation.progress.clock).to have_attributes(seconds: 300, display: "5:00")
      end
    end

    context "when a persisted score exceeds the selected final" do
      let(:current_lifecycle) { "in_progress" }
      let(:current_home_score) { 29 }
      let(:current_away_score) { 13 }
      let(:current_progress) do
        progress_for.call(quarter: 4, seconds: 60, display: "1:00")
      end

      it "fails closed" do
        expect { observation }.to raise_error(ArgumentError, "persisted sandbox score exceeds selected final")
      end
    end
  end
end
