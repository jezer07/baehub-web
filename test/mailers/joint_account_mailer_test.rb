require "test_helper"

class JointAccountMailerTest < ActionMailer::TestCase
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

  test "joint account created email" do
    email = JointAccountMailer.joint_account_created(@joint_account, @user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@user.email], email.to
    assert_includes email.subject, @joint_account.name
  end

  test "borrow transaction recorded email" do
    ledger_entry = @joint_account.joint_account_ledger_entries.create!(
      initiator: @user,
      direction: :partner_owes_joint_account,
      amount_cents: 10000,
      currency: "USD"
    )

    email = JointAccountMailer.borrow_transaction_recorded(ledger_entry, @user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@user.email], email.to
    assert_includes email.subject, @joint_account.name
  end

  test "settlement completed email" do
    settlement = @joint_account.joint_account_settlements.create!(
      settled_by: @user,
      total_amount_cents: 10000,
      currency: "USD",
      settlement_date: Date.current
    )

    email = JointAccountMailer.settlement_completed(settlement, @user)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@user.email], email.to
    assert_includes email.subject, @joint_account.name
  end

  test "outstanding balance reminder email" do
    balance = @joint_account.joint_account_balances.create!(
      user: @user,
      currency: "USD",
      balance_cents: -10000,
      borrowed_from_account_cents: 10000,
      lent_to_account_cents: 0
    )

    email = JointAccountMailer.outstanding_balance_reminder(balance)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [@user.email], email.to
    assert_includes email.subject, @joint_account.name
  end
end

