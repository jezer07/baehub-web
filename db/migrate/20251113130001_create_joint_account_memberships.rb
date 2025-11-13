class CreateJointAccountMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :joint_account_memberships do |t|
      t.references :joint_account, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member", limit: 20
      t.datetime :joined_at, null: false
      t.datetime :left_at
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :joint_account_memberships, %i[joint_account_id user_id], unique: true, name: "index_joint_account_memberships_uniqueness"
    add_index :joint_account_memberships, %i[joint_account_id active]
    add_index :joint_account_memberships, %i[user_id active]
  end
end

