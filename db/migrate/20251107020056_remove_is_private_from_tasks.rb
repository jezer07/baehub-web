class RemoveIsPrivateFromTasks < ActiveRecord::Migration[8.1]
  def change
    remove_column :tasks, :is_private, :boolean, default: false, null: false
  end
end
