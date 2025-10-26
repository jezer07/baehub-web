class AddDefaultCurrencyToCouples < ActiveRecord::Migration[8.0]
  def change
    add_column :couples, :default_currency, :string, null: false, default: "USD"
  end
end
