# frozen_string_literal: true

RSpec.describe Jumbotron::ObservationBatch do
  describe ".create" do
    context "when metadata is a non-empty Hash on MariaDB json_valid columns" do
      subject(:batch) do
        described_class.create!(
          provider: "espn",
          adapter_scope: "espn_nfl",
          observed_at: Time.utc(2026, 8, 26, 12, 0, 0),
          metadata: { "week" => 1, "scope" => "full_season" }
        )
      end

      let(:raw_metadata) do
        described_class.connection.select_value(
          described_class.sanitize_sql_array(
            [
              "SELECT metadata FROM jumbotron_observation_batches WHERE id = ?",
              batch.id
            ]
          )
        )
      end
      let(:raw_metadata_text) { raw_metadata.is_a?(String) ? raw_metadata : raw_metadata.to_json }

      it "persists without CheckViolation" do
        expect { batch }.not_to raise_error
      end

      it "is persisted" do
        batch
        expect(batch).to be_persisted
      end

      it "stores metadata as JSON without Ruby Hash#inspect" do
        batch
        expect(raw_metadata_text).not_to include("=>")
      end

      it "stores metadata as parseable JSON" do
        batch
        expect(JSON.parse(raw_metadata_text)).to eq("week" => 1, "scope" => "full_season")
      end
    end
  end
end
