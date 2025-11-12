class RemoveUnusedEventFieldsFromEvents < ActiveRecord::Migration[8.1]
  def change
    remove_column :events, :location, :string
    remove_column :events, :category, :string
    remove_column :events, :color, :string
    remove_column :events, :requires_response, :boolean, default: false, null: false
  end
end
