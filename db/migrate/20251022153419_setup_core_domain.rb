class SetupCoreDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :couples do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.date :anniversary_on
      t.string :timezone, null: false, default: "UTC"
      t.text :story

      t.timestamps
    end
    add_index :couples, :slug, unique: true

    change_table :users, bulk: true do |t|
      t.references :couple, foreign_key: true
      t.string :role, null: false, default: "partner"
      t.string :preferred_color
      t.string :timezone
      t.boolean :solo_mode, null: false, default: false
    end

    create_table :invitations do |t|
      t.references :couple, foreign_key: true
      t.references :sender, null: false, foreign_key: { to_table: :users }
      t.string :recipient_email
      t.string :code, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :expires_at, null: false
      t.datetime :redeemed_at
      t.datetime :revoked_at
      t.text :message

      t.timestamps
    end
    add_index :invitations, :code, unique: true

    create_table :tasks do |t|
      t.references :couple, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :assignee, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.datetime :due_at
      t.integer :status, null: false, default: 0
      t.integer :priority, null: false, default: 0
      t.boolean :is_private, null: false, default: false
      t.datetime :completed_at

      t.timestamps
    end
    add_index :tasks, %i[couple_id status]
    add_index :tasks, %i[couple_id due_at]

    create_table :events do |t|
      t.references :couple, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.boolean :all_day, null: false, default: false
      t.string :location
      t.string :category
      t.string :color
      t.string :recurrence_rule
      t.boolean :requires_response, null: false, default: false

      t.timestamps
    end
    add_index :events, %i[couple_id starts_at]

    create_table :event_responses do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.datetime :responded_at

      t.timestamps
    end
    add_index :event_responses, %i[event_id user_id], unique: true

    create_table :expenses do |t|
      t.references :couple, null: false, foreign_key: true
      t.references :spender, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "USD"
      t.string :split_strategy, null: false, default: "equal"
      t.date :incurred_on, null: false
      t.datetime :settled_at
      t.text :notes

      t.timestamps
    end
    add_index :expenses, %i[couple_id incurred_on]

    create_table :expense_shares do |t|
      t.references :expense, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.integer :amount_cents
      t.decimal :percentage, precision: 5, scale: 2

      t.timestamps
    end
    add_index :expense_shares, %i[expense_id user_id], unique: true

    create_table :reminders do |t|
      t.references :couple, null: false, foreign_key: true
      t.references :sender, foreign_key: { to_table: :users }
      t.references :recipient, foreign_key: { to_table: :users }
      t.string :channel, null: false, default: "push"
      t.datetime :deliver_at, null: false
      t.datetime :delivered_at
      t.string :status, null: false, default: "scheduled"
      t.text :message
      t.references :remindable, polymorphic: true, null: false

      t.timestamps
    end

    create_table :activity_logs do |t|
      t.references :couple, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.references :subject, polymorphic: true
      t.json :metadata, default: {}, null: false

      t.timestamps
    end
    add_index :activity_logs, %i[couple_id created_at]
  end
end
