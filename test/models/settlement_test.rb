require "test_helper"

class SettlementTest < ActiveSupport::TestCase
  setup do
    @couple = Couple.create!(name: "Test Couple", slug: "testcouple#{rand(10000)}", timezone: "UTC")
    @user_one = User.create!(
      email: "test1@example.com",
      name: "Test User One",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
    @user_two = User.create!(
      email: "test2@example.com",
      name: "Test User Two",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
  end

  test "amount_dollars setter converts to cents correctly" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      settled_on: Date.today
    )
    
    settlement.amount_dollars = 10.00
    assert_equal 1000, settlement.amount_cents
    
    settlement.amount_dollars = 0.01
    assert_equal 1, settlement.amount_cents
    
    settlement.amount_dollars = 99.99
    assert_equal 9999, settlement.amount_cents
  end

  test "amount_dollars getter returns correct dollar value from cents" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 5000,
      settled_on: Date.today,
      currency: "USD"
    )
    
    assert_equal 50.0, settlement.amount_dollars
  end

  test "amount_dollars setter handles decimal precision correctly" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      settled_on: Date.today
    )
    
    settlement.amount_dollars = 12.345
    assert_equal 1235, settlement.amount_cents
    
    settlement.amount_dollars = 12.344
    assert_equal 1234, settlement.amount_cents
  end

  test "amount_dollars setter handles invalid input" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      settled_on: Date.today
    )
    
    settlement.amount_dollars = "invalid"
    assert_nil settlement.amount_cents
    assert settlement.errors[:amount_dollars].any?
  end

  test "amount_cents must be present" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:amount_cents].any?
  end

  test "amount_cents must be greater than 0" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 0,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:amount_cents].any?
    
    settlement.amount_cents = -100
    assert_not settlement.valid?
  end

  test "amount_cents must be less than or equal to 100000 dollars" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 10_000_001,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:amount_cents].any?
    
    settlement.amount_cents = 10_000_000
    assert settlement.valid?
  end

  test "currency must be present and 3 characters" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 1000,
      settled_on: Date.today,
      currency: "US"
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:currency].any?
    
    settlement.currency = "USDA"
    assert_not settlement.valid?
    assert settlement.errors[:currency].any?
    
    settlement.currency = "USD"
    assert settlement.valid?
  end

  test "settled_on must be present" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 1000,
      currency: "USD"
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:settled_on].any?
  end

  test "payer and payee must be different" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_one,
      amount_cents: 1000,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:payee_id].any?
  end

  test "payer must belong to couple" do
    other_couple = Couple.create!(name: "Other Couple", slug: "othercouple#{rand(10000)}", timezone: "UTC")
    other_user = User.create!(
      email: "other@example.com",
      name: "Other User",
      password: "password123",
      password_confirmation: "password123",
      couple: other_couple
    )
    
    settlement = Settlement.new(
      couple: @couple,
      payer: other_user,
      payee: @user_two,
      amount_cents: 1000,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:payer].any?
  end

  test "payee must belong to couple" do
    other_couple = Couple.create!(name: "Other Couple", slug: "othercouple#{rand(10000)}", timezone: "UTC")
    other_user = User.create!(
      email: "other@example.com",
      name: "Other User",
      password: "password123",
      password_confirmation: "password123",
      couple: other_couple
    )
    
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: other_user,
      amount_cents: 1000,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_not settlement.valid?
    assert settlement.errors[:payee].any?
  end

  test "currency is converted to uppercase" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 1000,
      currency: "usd",
      settled_on: Date.today
    )
    
    settlement.valid?
    assert_equal "USD", settlement.currency
  end

  test "currency defaults to USD if blank" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 1000,
      settled_on: Date.today
    )
    
    settlement.valid?
    assert_equal "USD", settlement.currency
  end

  test "formatted_amount returns correct format with currency symbol" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 5000,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_equal "$50.00", settlement.formatted_amount
    
    settlement.currency = "EUR"
    assert_equal "€50.00", settlement.formatted_amount
    
    settlement.currency = "GBP"
    assert_equal "£50.00", settlement.formatted_amount
    
    settlement.currency = "JPY"
    assert_equal "¥50.00", settlement.formatted_amount
    
    settlement.currency = "CAD"
    assert_equal "C$50.00", settlement.formatted_amount
    
    settlement.currency = "AUD"
    assert_equal "A$50.00", settlement.formatted_amount
  end

  test "currency_symbol returns correct symbol for each currency" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 1000,
      settled_on: Date.today
    )
    
    settlement.currency = "USD"
    assert_equal "$", settlement.currency_symbol
    
    settlement.currency = "EUR"
    assert_equal "€", settlement.currency_symbol
    
    settlement.currency = "GBP"
    assert_equal "£", settlement.currency_symbol
    
    settlement.currency = "JPY"
    assert_equal "¥", settlement.currency_symbol
    
    settlement.currency = "CAD"
    assert_equal "C$", settlement.currency_symbol
    
    settlement.currency = "AUD"
    assert_equal "A$", settlement.currency_symbol
  end

  test "description returns correct text" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_cents: 5000,
      currency: "USD",
      settled_on: Date.today
    )
    
    assert_equal "Test User One paid Test User Two $50.00", settlement.description
  end

  test "valid settlement can be created and saved" do
    settlement = Settlement.new(
      couple: @couple,
      payer: @user_one,
      payee: @user_two,
      amount_dollars: 50.00,
      currency: "USD",
      settled_on: Date.today,
      notes: "Test payment"
    )
    
    assert settlement.valid?
    assert settlement.save
  end
end
