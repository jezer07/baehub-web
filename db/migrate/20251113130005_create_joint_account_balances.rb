class CreateJointAccountBalances < ActiveRecord::Migration[8.1]
  def change
    create_table :joint_account_balances do |t|
      t.references :joint_account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :currency, null: false, limit: 3
      t.integer :balance_cents, null: false, default: 0
      t.integer :borrowed_from_account_cents, null: false, default: 0
      t.integer :lent_to_account_cents, null: false, default: 0
      t.datetime :last_calculated_at, null: false

      t.timestamps
    end

    add_index :joint_account_balances, %i[joint_account_id user_id currency], unique: true, name: "index_joint_account_balances_uniqueness"
    add_index :joint_account_balances, %i[joint_account_id last_calculated_at]
    add_index :joint_account_balances, %i[user_id last_calculated_at]
  end
end

