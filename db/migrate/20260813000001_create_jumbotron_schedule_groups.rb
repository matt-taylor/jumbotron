# frozen_string_literal: true

class CreateJumbotronScheduleGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :jumbotron_schedule_groups do |t|
      t.references :season, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_seasons }
      t.references :season_phase, type: :bigint, foreign_key: { to_table: :jumbotron_season_phases }
      t.string :kind, null: false
      t.integer :number
      t.string :name, null: false
      t.timestamps
    end

    add_index :jumbotron_schedule_groups,
              %i[season_id season_phase_id kind name],
              unique: true,
              name: "idx_jumbotron_sg_identity"

    add_reference :jumbotron_games,
                  :schedule_group,
                  type: :bigint,
                  foreign_key: { to_table: :jumbotron_schedule_groups }
  end
end
