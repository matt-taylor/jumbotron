# frozen_string_literal: true

class CreateJumbotronSandboxProjections < ActiveRecord::Migration[8.1]
  def change
    create_table :jumbotron_sandbox_projections do |t|
      t.string :name, null: false
      t.references :source_season, null: false, foreign_key: { to_table: :jumbotron_seasons }
      t.references :source_anchor_phase, null: false, foreign_key: { to_table: :jumbotron_season_phases }
      t.references :sandbox_season,
                   null: false,
                   foreign_key: { to_table: :jumbotron_seasons },
                   index: { unique: true }
      t.string :adapter_id, null: false
      t.string :calendar_time_zone, null: false
      t.string :last_reset_fingerprint
      t.datetime :last_reset_at
      t.integer :last_date_shift_days
      t.timestamps
    end
    add_index :jumbotron_sandbox_projections, :name, unique: true

    create_table :jumbotron_sandbox_game_mappings do |t|
      t.references :sandbox_projection, null: false, foreign_key: { to_table: :jumbotron_sandbox_projections }
      t.references :source_game, null: false, foreign_key: { to_table: :jumbotron_games }
      t.references :sandbox_game,
                   null: false,
                   foreign_key: { to_table: :jumbotron_games },
                   index: { unique: true }
      t.decimal :home_spread, precision: 6, scale: 2, null: false
      t.decimal :total, precision: 6, scale: 2, null: false
      t.string :line_fingerprint, null: false
      t.timestamps
    end
    add_index :jumbotron_sandbox_game_mappings,
              %i[sandbox_projection_id source_game_id],
              unique: true,
              name: "idx_jumbotron_sandbox_mapping_source"
  end
end
