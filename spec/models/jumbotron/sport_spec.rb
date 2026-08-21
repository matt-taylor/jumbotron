# frozen_string_literal: true

RSpec.describe Jumbotron::Sport do
  describe ".create" do
    context "when name is present" do
      subject(:sport) { create(:jumbotron_sport, name: "Football") }

      it "persists the record" do
        expect(sport).to be_persisted
      end

      it "assigns a Jumbotron-owned primary key" do
        expect(sport.id).to be_a(Integer)
      end

      it "assigns a positive primary key" do
        expect(sport.id).to be_positive
      end
    end

    context "when name is blank" do
      subject(:sport) { build(:jumbotron_sport, name: "") }

      it "is invalid" do
        expect(sport).not_to be_valid
      end
    end
  end
end
