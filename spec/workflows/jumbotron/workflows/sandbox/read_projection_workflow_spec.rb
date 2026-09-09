# frozen_string_literal: true

RSpec.describe Jumbotron::Workflows::Sandbox::ReadProjectionWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(name:) }

    context "when the projection exists" do
      let(:projection) { create(:jumbotron_sandbox_projection, name: "apple-review") }
      let(:name) { projection.name }

      it "returns only the public projection DTO" do
        expect(result).to be_success
        expect(result.payload[:sandbox_projection]).to be_a(Jumbotron::Public::SandboxProjection)
        expect(result.payload[:sandbox_projection]).not_to be_a(ActiveRecord::Base)
      end
    end

    context "when the projection is missing" do
      let(:name) { "missing" }

      it { expect(result.http_status).to eq(:not_found) }
    end
  end
end
