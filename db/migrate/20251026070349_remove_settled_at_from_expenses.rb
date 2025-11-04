class RemoveSettledAtFromExpenses < ActiveRecord::Migration[8.1]
  def change
    remove_column :expenses, :settled_at, :datetime
  end
end
