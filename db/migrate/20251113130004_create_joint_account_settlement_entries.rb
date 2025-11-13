class CreateJointAccountSettlementEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :joint_account_settlement_entries do |t|
      t.references :joint_account_settlement, null: false, foreign_key: true, index: { name: "index_settlement_entries_on_settlement_id" }
      t.references :joint_account_ledger_entry, null: false, foreign_key: true, index: { name: "index_settlement_entries_on_ledger_entry_id" }

      t.timestamps
    end

    add_index :joint_account_settlement_entries, 
      %i[joint_account_settlement_id joint_account_ledger_entry_id], 
      unique: true, 
      name: "index_settlement_entries_uniqueness"
  end
end

