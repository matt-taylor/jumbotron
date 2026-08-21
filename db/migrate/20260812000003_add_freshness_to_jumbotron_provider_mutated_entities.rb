# frozen_string_literal: true

class AddFreshnessToJumbotronProviderMutatedEntities < ActiveRecord::Migration[7.2]
  TABLES = %w[
    jumbotron_games
    jumbotron_teams
    jumbotron_venues
    jumbotron_game_participants
  ].freeze

  def up
    TABLES.each do |table|
      add_column table, :observed_at, :datetime
      add_column table, :changed_at, :datetime
      execute <<~SQL.squish
        UPDATE #{table}
        SET observed_at = created_at, changed_at = created_at
        WHERE observed_at IS NULL OR changed_at IS NULL
      SQL
      change_column_null table, :observed_at, false
      change_column_null table, :changed_at, false
    end
  end

  def down
    TABLES.each do |table|
      remove_column table, :observed_at
      remove_column table, :changed_at
    end
  end
end
