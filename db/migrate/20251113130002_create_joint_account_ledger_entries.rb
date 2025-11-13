class CreateJointAccountLedgerEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :joint_account_ledger_entries do |t|
      t.references :joint_account, null: false, foreign_key: true
      t.references :initiator, null: false, foreign_key: { to_table: :users }
      t.references :counterparty, null: true, foreign_key: { to_table: :users }
      t.string :direction, null: false, limit: 50
      t.integer :amount_cents, null: false
      t.string :currency, null: false, limit: 3
      t.text :description
      t.text :metadata, null: false, default: "{}"
      t.datetime :settled_at
      t.string :settlement_reference, limit: 100

      t.timestamps
    end

    add_check_constraint :joint_account_ledger_entries, "amount_cents > 0", name: "positive_amount_check"
    
    add_index :joint_account_ledger_entries, %i[joint_account_id created_at]
    add_index :joint_account_ledger_entries, %i[joint_account_id settled_at]
    add_index :joint_account_ledger_entries, %i[initiator_id created_at]
    add_index :joint_account_ledger_entries, %i[counterparty_id created_at]
    add_index :joint_account_ledger_entries, :direction
  end
end

