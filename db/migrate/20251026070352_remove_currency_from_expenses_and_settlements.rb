class RemoveCurrencyFromExpensesAndSettlements < ActiveRecord::Migration[8.1]
  def change
    remove_column :expenses, :currency, :string
    remove_column :settlements, :currency, :string
  end
end
