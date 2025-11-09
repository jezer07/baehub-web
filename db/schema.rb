# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_09_051725) do
  create_table "activity_logs", force: :cascade do |t|
    t.string "action", null: false
    t.integer "couple_id", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.integer "subject_id"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["couple_id", "created_at"], name: "index_activity_logs_on_couple_id_and_created_at"
    t.index ["couple_id"], name: "index_activity_logs_on_couple_id"
    t.index ["subject_type", "subject_id"], name: "index_activity_logs_on_subject"
    t.index ["user_id"], name: "index_activity_logs_on_user_id"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "device_info"
    t.datetime "expires_at"
    t.datetime "last_used_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_api_tokens_on_expires_at"
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "couples", force: :cascade do |t|
    t.date "anniversary_on"
    t.datetime "created_at", null: false
    t.string "default_currency", limit: 3, default: "USD", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.text "story"
    t.string "timezone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_couples_on_slug", unique: true
  end

  create_table "event_responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "event_id", null: false
    t.datetime "responded_at"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["event_id", "user_id"], name: "index_event_responses_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_responses_on_event_id"
    t.index ["user_id"], name: "index_event_responses_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.boolean "all_day", default: false, null: false
    t.string "category"
    t.string "color"
    t.integer "couple_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.text "description"
    t.datetime "ends_at"
    t.string "location"
    t.string "recurrence_rule"
    t.boolean "requires_response", default: false, null: false
    t.datetime "starts_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["couple_id", "starts_at"], name: "index_events_on_couple_id_and_starts_at"
    t.index ["couple_id"], name: "index_events_on_couple_id"
    t.index ["creator_id"], name: "index_events_on_creator_id"
  end

  create_table "expense_shares", force: :cascade do |t|
    t.integer "amount_cents"
    t.datetime "created_at", null: false
    t.integer "expense_id", null: false
    t.decimal "percentage", precision: 5, scale: 2
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["expense_id", "user_id"], name: "index_expense_shares_on_expense_id_and_user_id", unique: true
    t.index ["expense_id"], name: "index_expense_shares_on_expense_id"
    t.index ["user_id"], name: "index_expense_shares_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.integer "couple_id", null: false
    t.datetime "created_at", null: false
    t.date "incurred_on", null: false
    t.text "notes"
    t.integer "spender_id", null: false
    t.string "split_strategy", default: "equal", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["couple_id", "incurred_on"], name: "index_expenses_on_couple_id_and_incurred_on"
    t.index ["couple_id"], name: "index_expenses_on_couple_id"
    t.index ["spender_id"], name: "index_expenses_on_spender_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.string "code", null: false
    t.integer "couple_id"
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.text "message"
    t.string "recipient_email"
    t.datetime "redeemed_at"
    t.datetime "revoked_at"
    t.integer "sender_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_invitations_on_code", unique: true
    t.index ["couple_id"], name: "index_invitations_on_couple_id"
    t.index ["sender_id"], name: "index_invitations_on_sender_id"
  end

  create_table "reminders", force: :cascade do |t|
    t.string "channel", default: "push", null: false
    t.integer "couple_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deliver_at", null: false
    t.datetime "delivered_at"
    t.text "message"
    t.integer "recipient_id"
    t.integer "remindable_id", null: false
    t.string "remindable_type", null: false
    t.integer "sender_id"
    t.string "status", default: "scheduled", null: false
    t.datetime "updated_at", null: false
    t.index ["couple_id"], name: "index_reminders_on_couple_id"
    t.index ["recipient_id"], name: "index_reminders_on_recipient_id"
    t.index ["remindable_type", "remindable_id"], name: "index_reminders_on_remindable"
    t.index ["sender_id"], name: "index_reminders_on_sender_id"
  end

  create_table "settlements", force: :cascade do |t|
    t.integer "amount_cents", null: false
    t.integer "couple_id", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.integer "payee_id", null: false
    t.integer "payer_id", null: false
    t.date "settled_on", null: false
    t.datetime "updated_at", null: false
    t.index ["couple_id", "settled_on"], name: "index_settlements_on_couple_id_and_settled_on"
    t.index ["couple_id"], name: "index_settlements_on_couple_id"
    t.index ["payee_id", "settled_on"], name: "index_settlements_on_payee_id_and_settled_on"
    t.index ["payee_id"], name: "index_settlements_on_payee_id"
    t.index ["payer_id", "settled_on"], name: "index_settlements_on_payer_id_and_settled_on"
    t.index ["payer_id"], name: "index_settlements_on_payer_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.integer "assignee_id"
    t.datetime "completed_at"
    t.integer "couple_id", null: false
    t.datetime "created_at", null: false
    t.integer "creator_id", null: false
    t.text "description"
    t.datetime "due_at"
    t.integer "priority", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["couple_id", "due_at"], name: "index_tasks_on_couple_id_and_due_at"
    t.index ["couple_id", "status"], name: "index_tasks_on_couple_id_and_status"
    t.index ["couple_id"], name: "index_tasks_on_couple_id"
    t.index ["creator_id"], name: "index_tasks_on_creator_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.integer "couple_id"
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "name", null: false
    t.string "preferred_color"
    t.boolean "prefers_dark_mode", default: false, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "partner", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.boolean "solo_mode", default: false, null: false
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["couple_id"], name: "index_users_on_couple_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "activity_logs", "couples"
  add_foreign_key "activity_logs", "users"
  add_foreign_key "api_tokens", "users"
  add_foreign_key "event_responses", "events"
  add_foreign_key "event_responses", "users"
  add_foreign_key "events", "couples"
  add_foreign_key "events", "users", column: "creator_id"
  add_foreign_key "expense_shares", "expenses"
  add_foreign_key "expense_shares", "users"
  add_foreign_key "expenses", "couples"
  add_foreign_key "expenses", "users", column: "spender_id"
  add_foreign_key "invitations", "couples"
  add_foreign_key "invitations", "users", column: "sender_id"
  add_foreign_key "reminders", "couples"
  add_foreign_key "reminders", "users", column: "recipient_id"
  add_foreign_key "reminders", "users", column: "sender_id"
  add_foreign_key "settlements", "couples"
  add_foreign_key "settlements", "users", column: "payee_id"
  add_foreign_key "settlements", "users", column: "payer_id"
  add_foreign_key "tasks", "couples"
  add_foreign_key "tasks", "users", column: "assignee_id"
  add_foreign_key "tasks", "users", column: "creator_id"
  add_foreign_key "users", "couples"
end
