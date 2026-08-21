# frozen_string_literal: true

RSpec.describe Jumbotron::Venue do
  describe ".create" do
    context "when name is present" do
      subject(:venue) { create(:jumbotron_venue) }

      it "persists independently of a Game" do
        expect(venue).to be_persisted
      end
    end
  end
end
