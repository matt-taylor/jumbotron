# frozen_string_literal: true

class AddProgressToJumbotronGames < ActiveRecord::Migration[8.1]
  def change
    change_table :jumbotron_games do |t|
      t.string :progress_state
      t.string :progress_segment_kind
      t.integer :progress_segment_number
      t.string :progress_clock_mode
      t.integer :progress_clock_seconds
      t.string :progress_clock_display
    end
  end
end
