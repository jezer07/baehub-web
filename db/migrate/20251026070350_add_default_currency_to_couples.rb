class AddDefaultCurrencyToCouples < ActiveRecord::Migration[8.1]
  def change
    add_column :couples, :default_currency, :string, limit: 3, null: false, default: "USD"
  end
end
