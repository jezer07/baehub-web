require "test_helper"

class ExpenseShareTest < ActiveSupport::TestCase
  setup do
    @expense = expenses(:one)
    @user = users(:one)
  end

  test "allows zero percentage share" do
    share = ExpenseShare.new(expense: @expense, user: @user, percentage: 0)

    assert_predicate share, :valid?, "Zero percentage shares should be permitted"
  end

  test "allows zero amount share" do
    share = ExpenseShare.new(expense: @expense, user: @user, amount_cents: 0)

    assert_predicate share, :valid?, "Zero amount shares should be permitted"
  end
end
