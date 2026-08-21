# frozen_string_literal: true

class CreateJumbotronFoundationalCatalog < ActiveRecord::Migration[8.1]
  def change
    create_sports
    create_leagues
    create_seasons
    create_season_phases
    create_provider_identities
    index_provider_identities
  end

  private

  def create_sports
    create_table :jumbotron_sports do |t|
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_leagues
    create_table :jumbotron_leagues do |t|
      t.references :sport, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_sports }
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_seasons
    create_table :jumbotron_seasons do |t|
      t.references :league, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_leagues }
      t.string :name, null: false
      t.date :starts_on
      t.date :ends_on
      t.timestamps
    end
  end

  def create_season_phases
    create_table :jumbotron_season_phases do |t|
      t.references :season, null: false, type: :bigint, foreign_key: { to_table: :jumbotron_seasons }
      t.string :name, null: false
      t.timestamps
    end
  end

  def create_provider_identities
    create_table :jumbotron_provider_identities do |t|
      t.string :provider, null: false, limit: 64
      t.string :object_namespace, null: false, limit: 64
      t.string :provider_id, null: false, limit: 191
      t.string :target_type, null: false
      t.bigint :target_id, null: false
      t.timestamps
    end
  end

  def index_provider_identities
    add_index :jumbotron_provider_identities,
              %i[provider object_namespace provider_id],
              unique: true,
              name: "idx_jumbotron_pi_identity"
    add_index :jumbotron_provider_identities,
              %i[target_type target_id],
              name: "idx_jumbotron_pi_target"
  end
end
