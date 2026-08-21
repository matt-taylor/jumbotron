# frozen_string_literal: true

class CreateJumbotronGameGraph < ActiveRecord::Migration[8.1]
  def change
    create_teams
    create_venues
    create_bookmakers
    create_games
    create_game_participants
    index_game_participants
  end

  private

  def create_teams
    create_table :jumbotron_teams do |t|
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_venues
    create_table :jumbotron_venues do |t|
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_bookmakers
    create_table :jumbotron_bookmakers do |t|
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_games
    create_table :jumbotron_games do |t|
      add_game_references(t)
      t.datetime :scheduled_at
      t.string :lifecycle, null: false, default: "scheduled"
      t.boolean :neutral_site, null: false, default: false
      t.timestamps
    end
  end

  def add_game_references(table)
    table.references :league, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_leagues }
    table.references :season, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_seasons }
    table.references :season_phase, type: :bigint, foreign_key: { to_table: :jumbotron_season_phases }
    table.references :venue, type: :bigint, foreign_key: { to_table: :jumbotron_venues }
  end

  def create_game_participants
    create_table :jumbotron_game_participants do |t|
      t.references :game, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_games }
      t.references :team, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_teams }
      t.string :role
      t.integer :score
      t.string :result
      t.timestamps
    end
  end

  def index_game_participants
    add_index :jumbotron_game_participants,
              %i[game_id team_id],
              unique: true,
              name: "idx_jumbotron_gp_game_team"
  end
end
