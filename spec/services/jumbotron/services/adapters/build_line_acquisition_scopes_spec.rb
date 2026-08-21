# frozen_string_literal: true

RSpec.describe Jumbotron::Services::Adapters::BuildLineAcquisitionScopes do
  describe ".call" do
    let(:adapter) { Jumbotron::Adapters::Espn::Nfl }
    let(:game) { create(:jumbotron_game) }
    let(:duplicate_game) { create(:jumbotron_game) }
    let(:incomplete_game) { create(:jumbotron_game) }

    before { adapter.register! unless adapter.registered? }

    context "when games share an acquisition scope" do
      let(:shared_scope) do
        { endpoint: :competition_odds, acquisition: { event_id: "1", competition_id: "1" } }
      end

      before do
        allow(adapter).to receive(:line_acquisition_scope_for) do |passed|
          next if passed.id == incomplete_game.id

          shared_scope
        end
      end

      subject(:result) { described_class.call(adapter: adapter, games: [game, duplicate_game, incomplete_game]) }

      it "deduplicates scopes and counts incomplete identities" do
        expect(result).to be_success
        expect(result.data[:scopes].size).to eq(1)
        expect(result.data[:skipped_incomplete_scope]).to eq(1)
      end
    end

    context "when scanning the generic builder" do
      subject(:source) do
        File.read(
          Jumbotron::Engine.root.join("app/services/jumbotron/services/adapters/build_line_acquisition_scopes.rb")
        )
      end

      it "does not hardcode ESPN query field names" do
        expect(source).not_to match(/\bevent_id\b|\bcompetition_id\b|\bdates\b|\bweek\b/)
      end
    end
  end
end
