require "test_helper"

class ExpenseShareTest < ActiveSupport::TestCase
  setup do
    @couple = couples(:one)
    @user = users(:one)
    # Create a new expense without existing shares to test zero values
    @expense = @couple.expenses.create!(
      spender: @user,
      title: "Test Zero Share",
      amount_cents: 10_000,
      incurred_on: Date.today,
      split_strategy: :custom_amounts
    )
  end

  test "allows zero percentage share" do
    share = ExpenseShare.new(expense: @expense, user: @user, percentage: 0)

    assert share.valid?, "Zero percentage shares should be permitted. Errors: #{share.errors.full_messages.join(', ')}"
  end

  test "allows zero amount share" do
    share = ExpenseShare.new(expense: @expense, user: @user, amount_cents: 0)

    assert share.valid?, "Zero amount shares should be permitted. Errors: #{share.errors.full_messages.join(', ')}"
  end
end
