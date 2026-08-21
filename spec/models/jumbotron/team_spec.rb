# frozen_string_literal: true

RSpec.describe Jumbotron::Team do
  describe ".create" do
    context "when name is present" do
      subject(:team) { create(:jumbotron_team, name: "Kansas City Chiefs") }

      it "persists the record" do
        expect(team).to be_persisted
      end

      it "assigns a Jumbotron-owned primary key" do
        expect(team.id).to be_a(Integer)
      end

      it "assigns a positive primary key" do
        expect(team.id).to be_positive
      end
    end
  end

  describe "schema" do
    it "does not store score" do
      expect(described_class.column_names).not_to include("score")
    end

    it "does not store role" do
      expect(described_class.column_names).not_to include("role")
    end

    it "does not store result" do
      expect(described_class.column_names).not_to include("result")
    end
  end
end
