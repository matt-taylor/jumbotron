# frozen_string_literal: true

RSpec.describe Jumbotron::Adapters::Cadence do
  describe "#interval_seconds" do
    it "converts week/day/hour/minute units" do
      expect(described_class.new(every: 1, unit: :week).interval_seconds).to eq(604_800)
      expect(described_class.new(every: 1, unit: :day).interval_seconds).to eq(86_400)
      expect(described_class.new(every: 1, unit: :hour).interval_seconds).to eq(3600)
      expect(described_class.new(every: 5, unit: :minute).interval_seconds).to eq(300)
    end

    it "rejects unknown units and non-positive every" do
      expect { described_class.new(every: 1, unit: :fortnight) }.to raise_error(ArgumentError)
      expect { described_class.new(every: 0, unit: :day) }.to raise_error(ArgumentError)
    end
  end
end
