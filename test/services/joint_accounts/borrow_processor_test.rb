require "test_helper"

class JointAccounts::BorrowProcessorTest < ActiveSupport::TestCase
  def setup
    @couple = couples(:one)
    @user = users(:one)
    @joint_account = JointAccount.create!(
      couple: @couple,
      created_by: @user,
      name: "Test Account",
      currency: "USD",
      status: :active
    )
    @joint_account.joint_account_memberships.create!(
      user: @user,
      active: true
    )
  end

  test "should process borrow transaction successfully" do
    params = {
      direction: "partner_owes_joint_account",
      amount_cents: 10000,
      currency: "USD",
      description: "Test borrow"
    }

    result = JointAccounts::BorrowProcessor.new(
      joint_account: @joint_account,
      initiator_user: @user,
      params: params
    ).call

    assert result[:success]
    assert_instance_of JointAccountLedgerEntry, result[:ledger_entry]
    assert_equal 10000, result[:ledger_entry].amount_cents
  end

  test "should fail with invalid amount" do
    params = {
      direction: "partner_owes_joint_account",
      amount_cents: 0,
      currency: "USD"
    }

    result = JointAccounts::BorrowProcessor.new(
      joint_account: @joint_account,
      initiator_user: @user,
      params: params
    ).call

    assert_not result[:success]
    assert_includes result[:errors].join, "Amount must be positive"
  end

  test "should fail if user is not a member" do
    other_user = User.create!(
      email: "other@example.com",
      password: "password",
      name: "Other User",
      couple: @couple
    )

    params = {
      direction: "partner_owes_joint_account",
      amount_cents: 10000,
      currency: "USD"
    }

    result = JointAccounts::BorrowProcessor.new(
      joint_account: @joint_account,
      initiator_user: other_user,
      params: params
    ).call

    assert_not result[:success]
    assert_includes result[:errors].join, "not a member"
  end

  test "should refresh balances after processing" do
    @joint_account.joint_account_balances.create!(
      user: @user,
      currency: "USD",
      balance_cents: 0,
      borrowed_from_account_cents: 0,
      lent_to_account_cents: 0
    )

    params = {
      direction: "partner_owes_joint_account",
      amount_cents: 10000,
      currency: "USD"
    }

    result = JointAccounts::BorrowProcessor.new(
      joint_account: @joint_account,
      initiator_user: @user,
      params: params
    ).call

    assert result[:success]
    
    balance = @joint_account.joint_account_balances.find_by(user: @user)
    assert balance.present?
  end
end

