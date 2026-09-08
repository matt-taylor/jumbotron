# frozen_string_literal: true

RSpec.describe Jumbotron::TeamKey do
  describe ".normalize" do
    it "derives a lowercase kebab-case semantic slug from a display name", :aggregate_failures do
      expect(described_class.normalize("Buffalo Bills")).to eq("buffalo-bills")
      expect(described_class.normalize("San Francisco 49ers")).to eq("san-francisco-49ers")
      expect(described_class.normalize("  Green Bay Packers ")).to eq("green-bay-packers")
    end

    it "collapses non-alphanumeric runs and rejects blank residue" do
      expect(described_class.normalize("!!!")).to eq("team")
    end
  end

  describe ".valid_format?" do
    it "accepts semantic kebab keys and rejects provider-style ids", :aggregate_failures do
      expect(described_class.valid_format?("buffalo-bills")).to be(true)
      expect(described_class.valid_format?("2")).to be(true) # format alone; Upsert never uses provider ids
      expect(described_class.valid_format?("Buffalo-Bills")).to be(false)
      expect(described_class.valid_format?("buffalo_bills")).to be(false)
      expect(described_class.valid_format?("")).to be(false)
    end
  end
end
