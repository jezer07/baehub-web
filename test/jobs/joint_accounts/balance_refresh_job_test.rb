require "test_helper"

class JointAccounts::BalanceRefreshJobTest < ActiveSupport::TestCase
  def setup
    @couple = couples(:one)
    @user = users(:one)
    @joint_account = JointAccount.create!(
      couple: @couple,
      created_by: @user,
      name: "Test Account",
      currency: "USD"
    )
  end

  test "should refresh balances for all users" do
    @joint_account.joint_account_memberships.create!(
      user: @user,
      active: true
    )

    assert_nothing_raised do
      JointAccounts::BalanceRefreshJob.perform_now(@joint_account.id)
    end
  end

  test "should handle non-existent joint account" do
    assert_nothing_raised do
      JointAccounts::BalanceRefreshJob.perform_now(999999)
    end
  end

  test "should refresh balance for specific user" do
    @joint_account.joint_account_memberships.create!(
      user: @user,
      active: true
    )

    assert_nothing_raised do
      JointAccounts::BalanceRefreshJob.perform_now(@joint_account.id, @user.id)
    end
  end
end

