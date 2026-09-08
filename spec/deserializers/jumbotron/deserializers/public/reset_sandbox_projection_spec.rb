# frozen_string_literal: true

RSpec.describe Jumbotron::Deserializers::Public::ResetSandboxProjection do
  describe ".call" do
    let(:params) do
      {
        sandbox: "apple-review",
        start_week: 3,
        anchor_day: 4,
        now: "2026-09-08T17:00:00Z"
      }
    end

    subject(:result) { described_class.call(params) }

    context "with structured reset inputs" do
      it "coerces the captured time" do
        expect(result.input).to have_attributes(
          sandbox: "apple-review",
          start_week: 3,
          anchor_day: 4,
          now: Time.utc(2026, 9, 8, 17, 0, 0)
        )
      end
    end

    context "when anchor day is not positive" do
      let(:params) { super().merge(anchor_day: 0) }

      it "fails validation" do
        expect(result).to be_failure
      end
    end
  end
end
