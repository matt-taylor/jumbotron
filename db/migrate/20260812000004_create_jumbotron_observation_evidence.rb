# frozen_string_literal: true

class CreateJumbotronObservationEvidence < ActiveRecord::Migration[7.2]
  def change
    create_table :jumbotron_observation_batches do |t|
      t.string :provider, null: false
      t.string :adapter_scope, null: false
      t.datetime :observed_at, null: false
      t.json :metadata
      t.timestamps
    end
    add_index :jumbotron_observation_batches,
              %i[provider adapter_scope observed_at],
              name: "idx_jumbotron_obs_batches_scope_time"

    create_table :jumbotron_historical_changes do |t|
      t.references :observation_batch,
                   null: false,
                   foreign_key: { to_table: :jumbotron_observation_batches },
                   index: { name: "idx_jumbotron_hist_changes_batch" }
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :attribute_name, null: false
      t.json :previous_value
      t.json :new_value
      t.datetime :observed_at, null: false
      t.string :provider, null: false
      t.timestamps
    end
    add_index :jumbotron_historical_changes,
              %i[subject_type subject_id],
              name: "idx_jumbotron_hist_changes_subject"
  end
end
