class CreateSettlements < ActiveRecord::Migration[8.1]
  def change
    create_table :settlements do |t|
      t.references :couple, null: false, foreign_key: true
      t.references :payer, null: false, foreign_key: { to_table: :users }
      t.references :payee, null: false, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "USD", limit: 3
      t.date :settled_on, null: false
      t.text :notes

      t.timestamps
    end

    add_index :settlements, %i[couple_id settled_on]
    add_index :settlements, %i[payer_id settled_on]
    add_index :settlements, %i[payee_id settled_on]
  end
end
