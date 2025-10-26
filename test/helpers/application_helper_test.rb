require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper
  
  self.use_transactional_tests = false
  
  def setup
  end

  test "contrasting_text_color returns black for light backgrounds" do
    assert_equal "#000000", contrasting_text_color("#ffffff")
    assert_equal "#000000", contrasting_text_color("#ffff00")
    assert_equal "#000000", contrasting_text_color("#00ff00")
    assert_equal "#000000", contrasting_text_color("#e5e7eb")
    assert_equal "#000000", contrasting_text_color("#f0f0f0")
  end

  test "contrasting_text_color returns white for dark backgrounds" do
    assert_equal "#ffffff", contrasting_text_color("#000000")
    assert_equal "#ffffff", contrasting_text_color("#0000ff")
    assert_equal "#ffffff", contrasting_text_color("#ff0000")
    assert_equal "#ffffff", contrasting_text_color("#1a1a1a")
    assert_equal "#ffffff", contrasting_text_color("#333333")
  end

  test "contrasting_text_color handles rgb format" do
    assert_equal "#000000", contrasting_text_color("rgb(255, 255, 255)")
    assert_equal "#ffffff", contrasting_text_color("rgb(0, 0, 0)")
    assert_equal "#000000", contrasting_text_color("rgb(255, 255, 0)")
    assert_equal "#ffffff", contrasting_text_color("rgb(255, 0, 0)")
  end

  test "contrasting_text_color handles rgba format" do
    assert_equal "#000000", contrasting_text_color("rgba(255, 255, 255, 1)")
    assert_equal "#ffffff", contrasting_text_color("rgba(0, 0, 0, 0.5)")
    assert_equal "#000000", contrasting_text_color("rgba(255, 255, 0, 0.8)")
  end

  test "contrasting_text_color returns fallback for invalid colors" do
    assert_equal "#111111", contrasting_text_color("")
    assert_equal "#111111", contrasting_text_color(nil)
    assert_equal "#111111", contrasting_text_color("invalid")
    assert_equal "#111111", contrasting_text_color("blue")
  end

  test "safe_event_color returns event color when valid" do
    event = Event.new(color: "#ff0000")
    assert_equal "#ff0000", safe_event_color(event)
  end

  test "safe_event_color returns fallback when color is blank" do
    event = Event.new(color: nil)
    assert_equal "#e5e7eb", safe_event_color(event)

    event = Event.new(color: "")
    assert_equal "#e5e7eb", safe_event_color(event)
  end

  test "safe_event_color returns fallback for invalid colors" do
    event = Event.new(color: "invalid")
    assert_equal "#e5e7eb", safe_event_color(event)

    event = Event.new(color: "blue")
    assert_equal "#e5e7eb", safe_event_color(event)
  end

  test "transaction_impact_for_user with expense transaction type" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    couple.update!(default_currency: "PHP")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    expense = couple.expenses.create!(spender: user_a, title: "Test", amount_cents: 10_000, incurred_on: Date.today, split_strategy: :equal)
    expense.expense_shares.create!(user: user_a, percentage: 50)
    expense.expense_shares.create!(user: user_b, percentage: 50)
    
    transaction = { type: :expense, object: expense }
    
    impact = transaction_impact_for_user(transaction, user_a)
    assert_equal 5_000, impact[:impact_cents]
    assert_equal couple.default_currency, impact[:currency]
  end

  test "transaction_impact_for_user with settlement transaction type" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    couple.update!(default_currency: "EUR")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    settlement = couple.settlements.create!(payer: user_a, payee: user_b, amount_cents: 5_000, settled_on: Date.today)
    
    transaction = { type: :settlement, object: settlement }
    
    impact = transaction_impact_for_user(transaction, user_a)
    assert_equal(-5_000, impact[:impact_cents])
    assert_equal couple.default_currency, impact[:currency]
  end

  test "transaction_impact_for_user with unknown transaction type returns zero impact" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    
    transaction = { type: :unknown, object: nil }
    
    impact = transaction_impact_for_user(transaction, user)
    assert_equal 0, impact[:impact_cents]
    assert_equal couple.default_currency, impact[:currency]
  end

  test "expense_impact_for_user when user is the spender positive impact" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    expense = couple.expenses.create!(spender: user_a, title: "Test", amount_cents: 10_000, incurred_on: Date.today, split_strategy: :equal)
    expense.expense_shares.create!(user: user_a, percentage: 50)
    expense.expense_shares.create!(user: user_b, percentage: 50)
    
    impact = expense_impact_for_user(expense, user_a)
    assert_equal 5_000, impact[:impact_cents]
    assert_equal couple.default_currency, impact[:currency]
  end

  test "expense_impact_for_user when user is not the spender negative impact" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    expense = couple.expenses.create!(spender: user_a, title: "Test", amount_cents: 10_000, incurred_on: Date.today, split_strategy: :equal)
    expense.expense_shares.create!(user: user_a, percentage: 50)
    expense.expense_shares.create!(user: user_b, percentage: 50)
    
    impact = expense_impact_for_user(expense, user_b)
    assert_equal(-5_000, impact[:impact_cents])
    assert_equal couple.default_currency, impact[:currency]
  end

  test "expense_impact_for_user with percentage split" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    expense = couple.expenses.create!(spender: user_a, title: "Test", amount_cents: 10_000, incurred_on: Date.today, split_strategy: :percentage)
    expense.expense_shares.create!(user: user_a, percentage: 70)
    expense.expense_shares.create!(user: user_b, percentage: 30)
    
    impact = expense_impact_for_user(expense, user_a)
    assert_equal 3_000, impact[:impact_cents]
  end

  test "expense_impact_for_user with custom amount split" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    expense = couple.expenses.create!(spender: user_a, title: "Test", amount_cents: 10_000, incurred_on: Date.today, split_strategy: :custom_amounts)
    expense.expense_shares.create!(user: user_a, amount_cents: 6_000)
    expense.expense_shares.create!(user: user_b, amount_cents: 4_000)
    
    impact = expense_impact_for_user(expense, user_a)
    assert_equal 4_000, impact[:impact_cents]
    assert_equal couple.default_currency, impact[:currency]
  end

  test "settlement_impact_for_user when user is the payer negative impact" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    settlement = couple.settlements.create!(payer: user_a, payee: user_b, amount_cents: 5_000, settled_on: Date.today)
    
    impact = settlement_impact_for_user(settlement, user_a)
    assert_equal(-5_000, impact[:impact_cents])
    assert_equal couple.default_currency, impact[:currency]
  end

  test "settlement_impact_for_user when user is the payee positive impact" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    
    settlement = couple.settlements.create!(payer: user_a, payee: user_b, amount_cents: 5_000, settled_on: Date.today)
    
    impact = settlement_impact_for_user(settlement, user_b)
    assert_equal 5_000, impact[:impact_cents]
    assert_equal couple.default_currency, impact[:currency]
  end

  test "settlement_impact_for_user when user is neither payer nor payee zero impact" do
    couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    user_a = User.create!(email: "a@test.com", name: "User A", password: "password123", password_confirmation: "password123", couple: couple)
    user_b = User.create!(email: "b@test.com", name: "User B", password: "password123", password_confirmation: "password123", couple: couple)
    user_c = User.create!(email: "c@test.com", name: "User C", password: "password123", password_confirmation: "password123")
    
    settlement = couple.settlements.create!(payer: user_a, payee: user_b, amount_cents: 5_000, settled_on: Date.today)
    
    impact = settlement_impact_for_user(settlement, user_c)
    assert_equal 0, impact[:impact_cents]
  end

  test "format_impact_badge positive impact shows green badge with plus sign" do
    badge = format_impact_badge(5_000, CurrencyCatalog.default_code)
    assert_includes badge, "+"
    assert_includes badge, "$50.00"
    assert_includes badge, "green"
  end

  test "format_impact_badge negative impact shows red badge with minus sign" do
    badge = format_impact_badge(-5_000, CurrencyCatalog.default_code)
    assert_includes badge, "−"
    assert_includes badge, "$50.00"
    assert_includes badge, "red"
  end

  test "format_impact_badge zero impact returns empty string" do
    badge = format_impact_badge(0, "USD")
    assert_equal "", badge
  end

  test "format_impact_badge different currencies show correct symbols" do
    badge_usd = format_impact_badge(5_000, "USD")
    assert_includes badge_usd, "$50.00"
    
    badge_eur = format_impact_badge(5_000, "EUR")
    assert_includes badge_eur, "€50.00"
    
    badge_gbp = format_impact_badge(5_000, "GBP")
    assert_includes badge_gbp, "£50.00"
    
    badge_jpy = format_impact_badge(5_000, "JPY")
    assert_includes badge_jpy, "¥50.00"
  end

  test "format_impact_badge amount formatting is correct" do
    badge = format_impact_badge(12_345, "USD")
    assert_includes badge, "$123.45"
    
    badge = format_impact_badge(1, "USD")
    assert_includes badge, "$0.01"
    
    badge = format_impact_badge(10_000, "USD")
    assert_includes badge, "$100.00"
  end
end
