class AddPrefersDarkModeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :prefers_dark_mode, :boolean, null: false, default: false
  end
end
