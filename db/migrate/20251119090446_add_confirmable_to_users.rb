class AddConfirmableToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_column :users, :unconfirmed_email, :string # Only if using reconfirmable

    add_index :users, :confirmation_token, unique: true

    # User.reset_column_information # Need for some types of updates, but usually safe to skip in simple add_column

    # Update all existing users as confirmed to avoid locking them out
    User.update_all(confirmed_at: DateTime.now)
  end

  def down
    remove_columns :users, :confirmation_token, :confirmed_at, :confirmation_sent_at, :unconfirmed_email
  end
end
