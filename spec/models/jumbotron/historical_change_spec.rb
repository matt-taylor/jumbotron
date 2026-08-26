# frozen_string_literal: true

RSpec.describe Jumbotron::HistoricalChange do
  describe ".create" do
    let(:observation_batch) { create(:jumbotron_observation_batch) }
    let(:observed_at) { Time.utc(2026, 8, 26, 12, 0, 0) }

    context "when persisting string previous_value and new_value on MariaDB json_valid columns" do
      subject(:change) do
        described_class.create!(
          observation_batch: observation_batch,
          subject_type: "Jumbotron::Game",
          subject_id: 1,
          attribute_name: "lifecycle",
          previous_value: "scheduled",
          new_value: "in_progress",
          observed_at: observed_at,
          provider: "espn"
        )
      end

      let(:raw_new_value) do
        described_class.connection.select_value(
          described_class.sanitize_sql_array(
            [
              "SELECT new_value FROM jumbotron_historical_changes WHERE id = ?",
              change.id
            ]
          )
        )
      end
      let(:raw_new_value_text) { raw_new_value.is_a?(String) ? raw_new_value : raw_new_value.to_json }

      it "persists without CheckViolation" do
        expect { change }.not_to raise_error
      end

      it "is persisted" do
        change
        expect(change).to be_persisted
      end

      it "stores new_value as JSON without Ruby Hash#inspect" do
        change
        expect(raw_new_value_text).not_to include("=>")
      end

      it "stores new_value as parseable JSON" do
        change
        expect(JSON.parse(raw_new_value_text)).to eq("in_progress")
      end
    end

    context "when persisting Time and Hash values" do
      subject(:change) do
        described_class.create!(
          observation_batch: observation_batch,
          subject_type: "Jumbotron::Game",
          subject_id: 1,
          attribute_name: "scheduled_at",
          previous_value: observed_at,
          new_value: { "status" => "moved" },
          observed_at: observed_at,
          provider: "espn"
        )
      end

      let(:raw_previous_value) do
        described_class.connection.select_value(
          described_class.sanitize_sql_array(
            [
              "SELECT previous_value FROM jumbotron_historical_changes WHERE id = ?",
              change.id
            ]
          )
        )
      end
      let(:raw_previous_value_text) do
        raw_previous_value.is_a?(String) ? raw_previous_value : raw_previous_value.to_json
      end

      it "persists without CheckViolation" do
        expect { change }.not_to raise_error
      end

      it "is persisted" do
        change
        expect(change).to be_persisted
      end

      it "stores previous_value as JSON without Ruby Hash#inspect" do
        change
        expect(raw_previous_value_text).not_to include("=>")
      end

      it "stores previous_value as parseable JSON" do
        change
        expect(JSON.parse(raw_previous_value_text)).to eq(observed_at.iso8601(3))
      end
    end
  end
end
