# frozen_string_literal: true

class AddNicknameToJumbotronTeams < ActiveRecord::Migration[8.0]
  def change
    add_column :jumbotron_teams, :nickname, :string
  end
end
