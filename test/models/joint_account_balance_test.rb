require "test_helper"

class JointAccountBalanceTest < ActiveSupport::TestCase
  def setup
    @couple = couples(:one)
    @user = users(:one)
    @joint_account = JointAccount.create!(
      couple: @couple,
      created_by: @user,
      name: "Test Account",
      currency: "USD"
    )
    @balance = @joint_account.joint_account_balances.create!(
      user: @user,
      currency: "USD",
      balance_cents: -5000,
      borrowed_from_account_cents: 10000,
      lent_to_account_cents: 5000
    )
  end

  test "should be valid with valid attributes" do
    assert @balance.valid?
  end

  test "should detect owing to joint account" do
    assert @balance.owes_to_joint_account?
    assert_not @balance.owed_by_joint_account?
  end

  test "should detect owed by joint account" do
    @balance.update!(balance_cents: 5000)
    assert @balance.owed_by_joint_account?
    assert_not @balance.owes_to_joint_account?
  end

  test "should detect balanced state" do
    @balance.update!(balance_cents: 0)
    assert @balance.balanced?
  end

  test "should return currency symbol" do
    assert_equal "$", @balance.currency_symbol
  end
end

