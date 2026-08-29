# frozen_string_literal: true

class AddGamePresentationContractFields < ActiveRecord::Migration[8.0]
  def change
    change_table :jumbotron_game_participants, bulk: true do |t|
      t.string :record_summary_entering
      t.string :record_summary_current
      t.string :record_summary_post_game
      t.datetime :record_observed_at
    end

    change_table :jumbotron_venues, bulk: true do |t|
      t.string :city
      t.string :region
    end

    add_column :jumbotron_teams, :abbreviation, :string
  end
end
