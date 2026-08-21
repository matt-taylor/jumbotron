# frozen_string_literal: true

class CreateJumbotronLineObservations < ActiveRecord::Migration[8.1]
  def change
    add_column :jumbotron_bookmakers, :observed_at, :datetime
    add_column :jumbotron_bookmakers, :changed_at, :datetime
    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE jumbotron_bookmakers
          SET observed_at = created_at, changed_at = created_at
          WHERE observed_at IS NULL OR changed_at IS NULL
        SQL
      end
    end
    change_column_null :jumbotron_bookmakers, :observed_at, false
    change_column_null :jumbotron_bookmakers, :changed_at, false

    create_table :jumbotron_line_observations do |t|
      t.references :game, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_games }
      t.references :bookmaker, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_bookmakers }
      t.references :observation_batch, null: false, type: :bigint,
                                       foreign_key: { to_table: :jumbotron_observation_batches }
      t.string :market, null: false, limit: 32
      t.string :outcome, null: false, limit: 32
      t.string :source, null: false, limit: 32
      t.decimal :line_value, precision: 8, scale: 3
      t.integer :price_american
      t.datetime :observed_at, null: false
      t.datetime :changed_at, null: false
      t.timestamps
    end

    add_index :jumbotron_line_observations,
              %i[game_id bookmaker_id market outcome source observed_at],
              name: "idx_jumbotron_line_obs_latest"
  end
end
