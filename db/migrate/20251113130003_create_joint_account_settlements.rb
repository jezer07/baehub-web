class CreateJointAccountSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :joint_account_settlements do |t|
      t.references :joint_account, null: false, foreign_key: true
      t.references :settled_by, null: false, foreign_key: { to_table: :users }
      t.integer :total_amount_cents, null: false
      t.string :currency, null: false, limit: 3
      t.date :settlement_date, null: false
      t.text :notes
      t.string :payment_method, limit: 50
      t.text :metadata, null: false, default: "{}"

      t.timestamps
    end

    add_check_constraint :joint_account_settlements, "total_amount_cents > 0", name: "positive_settlement_amount_check"
    
    add_index :joint_account_settlements, %i[joint_account_id settlement_date]
    add_index :joint_account_settlements, %i[settled_by_id created_at]
  end
end

