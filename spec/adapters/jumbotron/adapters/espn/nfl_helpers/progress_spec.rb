# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Espn::NflHelpers::Progress do
  let(:fixture_root) { Jumbotron::Engine.root.join("spec/fixtures/espn/nfl") }
  let(:status_payload) { JSON.parse(File.read(fixture_root.join(status_file))) }
  let(:status) { Jumbotron::Deserializers::Clients::Espn::Status.call(status_payload) }

  describe ".call" do
    context "when lifecycle is scheduled" do
      let(:status_file) { "progress/status_in_progress_q3.json" }

      subject(:result) { described_class.call(status, lifecycle: "scheduled") }

      it "returns nil even when ESPN supplies a period" do
        expect(result).to be_nil
      end
    end

    context "when lifecycle is postponed" do
      let(:status_file) { "progress/status_in_progress_q3.json" }

      subject(:result) { described_class.call(status, lifecycle: "postponed") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when lifecycle is cancelled" do
      let(:status_file) { "progress/status_in_progress_q3.json" }

      subject(:result) { described_class.call(status, lifecycle: "cancelled") }

      it "returns nil" do
        expect(result).to be_nil
      end
    end

    context "when regulation play is in progress" do
      let(:status_file) { "progress/status_in_progress_q3.json" }

      subject(:result) { described_class.call(status, lifecycle: "in_progress") }

      it "maps period 3 to an active remaining quarter clock" do
        expect(result.state).to eq("active")
        expect(result.segment).to have_attributes(kind: "quarter", number: 3)
        expect(result.clock).to have_attributes(mode: "remaining", seconds: 261, display: "4:21")
      end
    end

    context "when ESPN indicates intermission after the second quarter" do
      let(:status_file) { "progress/status_halftime.json" }

      subject(:result) { described_class.call(status, lifecycle: "in_progress") }

      it "maps to intermission on quarter 2 with no clock" do
        expect(result.state).to eq("intermission")
        expect(result.segment).to have_attributes(kind: "quarter", number: 2)
        expect(result.clock).to be_nil
      end

      it "does not use a competitive half segment" do
        expect(result.segment.kind).not_to eq("half")
      end

      it "does not use segment number 1 for intermission" do
        expect(result.segment.number).not_to eq(1)
      end
    end

    context "when ESPN period is 5" do
      let(:status_file) { "progress/status_overtime.json" }

      subject(:result) { described_class.call(status, lifecycle: "in_progress") }

      it "maps to the first overtime period" do
        expect(result.state).to eq("active")
        expect(result.segment).to have_attributes(kind: "overtime", number: 1)
        expect(result.clock).to have_attributes(mode: "remaining", seconds: 432, display: "7:12")
      end
    end

    context "when the game is completed" do
      let(:status_payload) do
        JSON.parse(File.read(fixture_root.join("scoreboard_2025_w1.json")))
            .fetch("events").first.fetch("competitions").first.fetch("status")
      end

      subject(:result) { described_class.call(status, lifecycle: "completed") }

      it "retains the final quarter clock" do
        expect(result.state).to eq("active")
        expect(result.segment).to have_attributes(kind: "quarter", number: 4)
        expect(result.clock).to have_attributes(mode: "remaining", seconds: 0, display: "0:00")
      end
    end
  end
end
