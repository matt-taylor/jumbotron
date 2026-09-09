# frozen_string_literal: true

class CreateJumbotronSandboxGamePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :jumbotron_sandbox_game_plans do |t|
      t.references :game,
                   null: false,
                   foreign_key: { to_table: :jumbotron_games },
                   index: { unique: true }
      t.integer :home_score, null: false
      t.integer :away_score, null: false
      t.datetime :selected_at, null: false
      t.timestamps
    end
  end
end
