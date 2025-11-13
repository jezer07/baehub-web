class CreateJointAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :joint_accounts do |t|
      t.references :couple, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.string :currency, null: false, default: "USD", limit: 3
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :status, null: false, default: "active", limit: 20
      t.text :settings, null: false, default: "{}"

      t.timestamps
    end

    add_index :joint_accounts, %i[couple_id status]
  end
end

