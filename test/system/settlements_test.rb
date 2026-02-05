require "application_system_test_case"

class SettlementsTest < ApplicationSystemTestCase
  setup do
    @couple = Couple.create!(name: "Test Couple", slug: "testcouple#{rand(10000)}", timezone: "UTC")
    @user_a = User.create!(
      email: "usera@system.test",
      name: "User A",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple,
      confirmed_at: Time.current
    )
    @user_b = User.create!(
      email: "userb@system.test",
      name: "User B",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple,
      confirmed_at: Time.current
    )

    expense = @couple.expenses.create!(
      spender: @user_a,
      title: "Test Expense",
      amount_cents: 10_000,
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

  test "settlement form displays shared currency symbol" do
    @couple.update!(default_currency: "PHP")
    visit new_settlement_path

    assert_selector "#settlement_currency_symbol", text: "₱"
  end

  test "edit form shows update payment button" do
    settlement = @couple.settlements.create!(
      payer: @user_b,
      payee: @user_a,
      amount_cents: 3000,
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
