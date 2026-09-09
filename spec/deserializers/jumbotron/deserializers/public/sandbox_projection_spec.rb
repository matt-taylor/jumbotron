# frozen_string_literal: true

RSpec.describe Jumbotron::Deserializers::Public::SandboxProjection do
  describe ".call" do
    subject(:result) { described_class.call(params) }

    context "with a name" do
      let(:params) { { name: "apple-review" } }

      it "returns a typed request" do
        expect(result).to be_success
        expect(result.input).to eq(Jumbotron::Public::SandboxProjectionRequest.new(name: "apple-review"))
      end
    end

    context "without a name" do
      let(:params) { {} }

      it { expect(result).not_to be_success }
    end
  end
end
