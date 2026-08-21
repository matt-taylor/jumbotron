# frozen_string_literal: true

RSpec.describe Jumbotron::Bookmaker do
  describe ".create" do
    context "when name is present" do
      subject(:bookmaker) { create(:jumbotron_bookmaker, name: "DraftKings") }

      it "persists with a Jumbotron-owned primary key" do
        expect(bookmaker).to be_persisted
      end
    end
  end

  describe "schema" do
    it "does not store an acquisition provider id" do
      expect(described_class.column_names).not_to include("espn_id")
    end
  end
end
