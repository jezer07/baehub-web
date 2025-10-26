require "application_system_test_case"

class SettlementsTest < ApplicationSystemTestCase
  setup do
    @couple = Couple.create!(name: "Test Couple", slug: "testcouple#{rand(10000)}", timezone: "UTC")
    @user_a = User.create!(
      email: "usera@system.test",
      name: "User A",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
    @user_b = User.create!(
      email: "userb@system.test",
      name: "User B",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
    
    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Test Expense",
      amount_cents: 10_000,
      currency: "USD",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    expense.expense_shares.create!(user: @user_a, percentage: 50)
    expense.expense_shares.create!(user: @user_b, percentage: 50)
    
    sign_in @user_a
  end

  test "create settlement from balance summary" do
    visit expenses_path
    
    assert_text "User B owes you"
    assert_text "$50.00"
    
    click_link "Settle Up"
    
    assert_field "settlement_amount_dollars", with: "50.00"
    assert_selector "input[type='radio'][value='#{@user_b.id}']:checked"
    
    click_button "Record Payment"
    
    assert_text "Settlement recorded successfully"
    assert_current_path expenses_path
    
    assert_text "All settled up"
  end

  test "create settlement manually" do
    visit new_settlement_path
    
    choose "settlement_payer_id_#{@user_b.id}"
    
    fill_in "settlement_amount_dollars", with: "30.00"
    
    select "USD ($)", from: "settlement_currency"
    
    fill_in "settlement_settled_on", with: Date.today
    
    fill_in "settlement_notes", with: "Partial payment"
    
    click_button "Record Payment"
    
    assert_text "Settlement recorded successfully"
    assert_current_path expenses_path
    
    assert_text "$20.00"
  end

  test "edit settlement" do
    settlement = @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 3000,
      currency: "USD",
      settled_on: Date.today,
      notes: "Original payment"
    )
    
    visit expenses_path
    
    within "li", text: "User B paid you" do
      click_link title: "Edit this payment"
    end
    
    assert_current_path edit_settlement_path(settlement)
    
    fill_in "settlement_amount_dollars", with: "40.00"
    
    fill_in "settlement_notes", with: "Updated payment"
    
    click_button "Update Payment"
    
    assert_text "Settlement updated successfully"
    assert_current_path expenses_path
  end

  test "delete settlement" do
    settlement = @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 5000,
      currency: "USD",
      settled_on: Date.today
    )
    
    visit edit_settlement_path(settlement)
    
    accept_confirm do
      click_button "Delete Payment"
    end
    
    assert_text "Settlement was successfully deleted"
    assert_current_path expenses_path
    
    assert_text "User B owes you"
    assert_text "$50.00"
  end

  test "multi-currency settlement" do
    eur_expense = @couple.expenses.create!(
      spender: @user_b,
      title: "EUR Expense",
      amount_cents: 8000,
      currency: "EUR",
      incurred_on: Date.today,
      split_strategy: :equal
    )
    eur_expense.expense_shares.create!(user: @user_a, percentage: 50)
    eur_expense.expense_shares.create!(user: @user_b, percentage: 50)
    
    visit expenses_path
    
    assert_text "User B owes you"
    assert_text "$50.00"
    
    assert_text "You owe User B"
    assert_text "€40.00"
    
    visit new_settlement_path(payer_id: @user_a.id, payee_id: @user_b.id, amount: "40.00", currency: "EUR")
    
    assert_field "settlement_amount_dollars", with: "40.00"
    assert_selector("select#settlement_currency option[selected]", text: "EUR (€)")
    
    click_button "Record Payment"
    
    assert_text "Settlement recorded successfully"
    
    within ".bg-gradient-to-r.from-blue-50" do
      assert_text "User B owes you"
      assert_text "$50.00"
      assert_no_text "€40.00"
    end
  end

  test "overpayment scenario balance flips" do
    visit new_settlement_path
    
    choose "settlement_payer_id_#{@user_b.id}"
    
    fill_in "settlement_amount_dollars", with: "100.00"
    
    click_button "Record Payment"
    
    assert_text "Settlement recorded successfully"
    
    assert_text "You owe User B"
    assert_text "$50.00"
  end

  test "settlement form validates required fields" do
    visit new_settlement_path
    
    fill_in "settlement_amount_dollars", with: ""
    
    click_button "Record Payment"
    
    assert_text "prevented this settlement from being saved"
  end

  test "settlement form shows currency selector" do
    visit new_settlement_path
    
    assert_selector "select#settlement_currency"
    assert_text "Currency"
    
    currencies = ["USD ($)", "EUR (€)", "GBP (£)", "JPY (¥)", "CAD (C$)", "AUD (A$)"]
    currencies.each do |currency|
      assert_selector "option", text: currency
    end
  end

  test "edit form shows update payment button" do
    settlement = @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 3000,
      currency: "USD",
      settled_on: Date.today
    )
    
    visit edit_settlement_path(settlement)
    
    assert_button "Update Payment"
    assert_no_button "Record Payment"
  end

  test "new form shows record payment button" do
    visit new_settlement_path
    
    assert_button "Record Payment"
    assert_no_button "Update Payment"
  end

  test "transaction history shows edit links for settlements" do
    settlement = @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 3000,
      currency: "USD",
      settled_on: Date.today
    )
    
    visit expenses_path
    
    within "li", text: "User B paid you" do
      assert_link title: "Edit this payment"
    end
  end

  test "balance summary description is user-friendly" do
    visit expenses_path
    
    within ".bg-gradient-to-r.from-blue-50" do
      assert_text "Your current balance after all expenses and payments"
    end
  end
end

