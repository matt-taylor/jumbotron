# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Public::ReadSandboxProjection do
  describe ".call" do
    subject(:result) { described_class.call(name:) }

    context "when the named projection exists" do
      let(:projection) { create(:jumbotron_sandbox_projection, name: "apple-review") }
      let(:name) { projection.name }

      it "returns the persisted projection for assembly" do
        expect(result).to be_success
        expect(result.data[:projection]).to eq(projection)
      end
    end

    context "when the named projection is missing" do
      let(:name) { "missing" }

      it "returns a stable not-found failure" do
        expect(result).not_to be_success
        expect(result.errors.first.code).to eq("sandbox_not_found")
      end
    end
  end
end
