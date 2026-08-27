# frozen_string_literal: true

class AddKeyToJumbotronTeams < ActiveRecord::Migration[8.1]
  def up
    add_column :jumbotron_teams, :key, :string, limit: 191
    backfill_keys!
    change_column_null :jumbotron_teams, :key, false
    add_index :jumbotron_teams, :key, unique: true, name: "index_jumbotron_teams_on_key"
  end

  def down
    remove_index :jumbotron_teams, name: "index_jumbotron_teams_on_key"
    remove_column :jumbotron_teams, :key
  end

  private

  def backfill_keys!
    say_with_time "backfill jumbotron_teams.key" do
      taken = {}
      connection.select_all("SELECT id, name FROM jumbotron_teams ORDER BY id").each do |row|
        key = allocate_key(normalize_name(row["name"]), taken)
        taken[key] = true
        connection.execute(
          "UPDATE jumbotron_teams SET `key` = #{connection.quote(key)} WHERE id = #{row['id'].to_i}"
        )
      end
    end
  end

  def normalize_name(name)
    slug = name.to_s.unicode_normalize(:nfc).downcase
    slug = slug.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
    slug = "team" if slug.blank?
    slug
  end

  def allocate_key(base, taken)
    return base unless taken[base]

    suffix = 2
    loop do
      candidate = "#{base}-#{suffix}"
      return candidate unless taken[candidate]

      suffix += 1
    end
  end
end
