require "test_helper"

class CoupleTest < ActiveSupport::TestCase
  setup do
    @couple = Couple.create!(name: "Test Couple", slug: "test#{rand(10000)}", timezone: "UTC")
    @user_a = User.create!(
      email: "usera@example.com",
      name: "User A",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
    @user_b = User.create!(
      email: "userb@example.com",
      name: "User B",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
  end

  test "calculate_balance with basic expense splitting" do
    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Groceries",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    
    expense.expense_shares.create!(user: @user_a, percentage: 50)
    expense.expense_shares.create!(user: @user_b, percentage: 50)
    
    balance_data = @couple.calculate_balance
    
    assert_equal 1, balance_data[:summary].length
    summary = balance_data[:summary].first
    
    assert_equal @user_b, summary[:debtor]
    assert_equal @user_a, summary[:creditor]
    assert_equal 5_000, summary[:amount_cents]
    assert_equal "USD", summary[:currency]
  end

  test "calculate_balance with multiple expenses" do
    expense_a = @couple.expenses.create!(
      spender: @user_a,
      title: "Groceries",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense_a.expense_shares.create!(user: @user_a, percentage: 50)
    expense_a.expense_shares.create!(user: @user_b, percentage: 50)
    
    expense_b = @couple.expenses.create!(
      spender: @user_b,
      title: "Dinner",
      amount_cents: 8_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense_b.expense_shares.create!(user: @user_a, percentage: 50)
    expense_b.expense_shares.create!(user: @user_b, percentage: 50)
    
    balance_data = @couple.calculate_balance
    
    assert_equal 1, balance_data[:summary].length
    summary = balance_data[:summary].first
    
    assert_equal @user_b, summary[:debtor]
    assert_equal @user_a, summary[:creditor]
    assert_equal 1_000, summary[:amount_cents]
    assert_equal "USD", summary[:currency]
  end

  test "calculate_balance settlement reduces balance" do
    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Groceries",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense.expense_shares.create!(user: @user_a, percentage: 50)
    expense.expense_shares.create!(user: @user_b, percentage: 50)
    
    @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 3_000,
      currency: "USD",
      settled_on: Date.today
    )
    
    balance_data = @couple.calculate_balance
    
    assert_equal 1, balance_data[:summary].length
    summary = balance_data[:summary].first
    
    assert_equal @user_b, summary[:debtor]
    assert_equal @user_a, summary[:creditor]
    assert_equal 2_000, summary[:amount_cents]
  end

  test "calculate_balance settlement clears balance" do
    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Groceries",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense.expense_shares.create!(user: @user_a, percentage: 50)
    expense.expense_shares.create!(user: @user_b, percentage: 50)
    
    @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 5_000,
      currency: "USD",
      settled_on: Date.today
    )
    
    balance_data = @couple.calculate_balance
    
    assert_equal 0, balance_data[:summary].length
  end

  test "calculate_balance overpayment scenario" do
    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Groceries",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense.expense_shares.create!(user: @user_a, percentage: 50)
    expense.expense_shares.create!(user: @user_b, percentage: 50)
    
    @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 10_000,
      currency: "USD",
      settled_on: Date.today
    )
    
    balance_data = @couple.calculate_balance
    
    assert_equal 1, balance_data[:summary].length
    summary = balance_data[:summary].first
    
    assert_equal @user_a, summary[:debtor]
    assert_equal @user_b, summary[:creditor]
    assert_equal 5_000, summary[:amount_cents]
  end

  test "calculate_balance multi-currency handling" do
    expense_usd = @couple.expenses.create!(
      spender: @user_a,
      title: "Groceries",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense_usd.expense_shares.create!(user: @user_a, percentage: 50)
    expense_usd.expense_shares.create!(user: @user_b, percentage: 50)
    
    expense_eur = @couple.expenses.create!(
      spender: @user_b,
      title: "Concert tickets",
      amount_cents: 8_000,
      currency: "EUR",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense_eur.expense_shares.create!(user: @user_a, percentage: 50)
    expense_eur.expense_shares.create!(user: @user_b, percentage: 50)
    
    balance_data = @couple.calculate_balance
    
    assert_equal 2, balance_data[:summary].length
    assert_equal 2, balance_data[:balances_by_currency].keys.length
    assert balance_data[:balances_by_currency].key?("USD")
    assert balance_data[:balances_by_currency].key?("EUR")
    
    usd_summary = balance_data[:summary].find { |s| s[:currency] == "USD" }
    eur_summary = balance_data[:summary].find { |s| s[:currency] == "EUR" }
    
    assert_equal @user_b, usd_summary[:debtor]
    assert_equal @user_a, usd_summary[:creditor]
    assert_equal 5_000, usd_summary[:amount_cents]
    
    assert_equal @user_a, eur_summary[:debtor]
    assert_equal @user_b, eur_summary[:creditor]
    assert_equal 4_000, eur_summary[:amount_cents]
  end

  test "calculate_balance complex scenario with multiple expenses and settlements" do
    expense_1 = @couple.expenses.create!(
      spender: @user_a,
      title: "Rent",
      amount_cents: 100_000,
      currency: "USD",
      incurred_on: Date.today - 5,
      split_strategy: :equal
    )
    expense_1.expense_shares.create!(user: @user_a, percentage: 50)
    expense_1.expense_shares.create!(user: @user_b, percentage: 50)
    
    expense_2 = @couple.expenses.create!(
      spender: @user_b,
      title: "Utilities",
      amount_cents: 20_000,
      currency: "USD",
      incurred_on: Date.today - 3,
      split_strategy: :equal
    )
    expense_2.expense_shares.create!(user: @user_a, percentage: 50)
    expense_2.expense_shares.create!(user: @user_b, percentage: 50)
    
    @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 30_000,
      currency: "USD",
      settled_on: Date.today - 1
    )
    
    expense_3 = @couple.expenses.create!(
      spender: @user_a,
      title: "Groceries",
      amount_cents: 15_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense_3.expense_shares.create!(user: @user_a, percentage: 50)
    expense_3.expense_shares.create!(user: @user_b, percentage: 50)
    
    balance_data = @couple.calculate_balance
    
    assert_equal 1, balance_data[:summary].length
    summary = balance_data[:summary].first
    
    assert_equal @user_b, summary[:debtor]
    assert_equal @user_a, summary[:creditor]
    assert_equal 17_500, summary[:amount_cents]
    assert_equal "USD", summary[:currency]
  end

  test "calculate_balance empty state with no expenses or settlements" do
    balance_data = @couple.calculate_balance
    
    assert_equal 0, balance_data[:summary].length
    assert_equal({}, balance_data[:balances_by_currency])
  end

  test "calculate_balance custom split with 70/30 percentage" do
    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Shared subscription",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :percentage
    )
    expense.expense_shares.create!(user: @user_a, percentage: 70)
    expense.expense_shares.create!(user: @user_b, percentage: 30)
    
    balance_data = @couple.calculate_balance
    
    assert_equal 1, balance_data[:summary].length
    summary = balance_data[:summary].first
    
    assert_equal @user_b, summary[:debtor]
    assert_equal @user_a, summary[:creditor]
    assert_equal 3_000, summary[:amount_cents]
  end

  test "calculate_balance custom split with exact amounts" do
    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Shared items",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :custom_amounts
    )
    expense.expense_shares.create!(user: @user_a, amount_cents: 6_000)
    expense.expense_shares.create!(user: @user_b, amount_cents: 4_000)
    
    balance_data = @couple.calculate_balance
    
    assert_equal 1, balance_data[:summary].length
    summary = balance_data[:summary].first
    
    assert_equal @user_b, summary[:debtor]
    assert_equal @user_a, summary[:creditor]
    assert_equal 4_000, summary[:amount_cents]
  end

  test "calculate_balance returns empty when couple has less than 2 users" do
    single_couple = Couple.create!(name: "Single Couple", slug: "single#{rand(10000)}", timezone: "UTC")
    single_user = User.create!(
      email: "single@example.com",
      name: "Single User",
      password: "password123",
      password_confirmation: "password123",
      couple: single_couple
    )
    
    balance_data = single_couple.calculate_balance
    
    assert_equal 0, balance_data[:summary].length
    assert_equal({}, balance_data[:balances_by_currency])
  end
end

