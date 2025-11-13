require "test_helper"

class JointAccountLedgerEntryTest < ActiveSupport::TestCase
  def setup
    @couple = couples(:one)
    @user = users(:one)
    @joint_account = JointAccount.create!(
      couple: @couple,
      created_by: @user,
      name: "Test Account",
      currency: "USD"
    )
    @entry = @joint_account.joint_account_ledger_entries.build(
      initiator: @user,
      direction: :partner_owes_joint_account,
      amount_cents: 10000,
      currency: "USD"
    )
  end

  test "should be valid with valid attributes" do
    assert @entry.valid?
  end

  test "should require positive amount" do
    @entry.amount_cents = 0
    assert_not @entry.valid?

    @entry.amount_cents = -100
    assert_not @entry.valid?
  end

  test "should require direction" do
    @entry.direction = nil
    assert_not @entry.valid?
  end

  test "should mark as settled" do
    @entry.save!
    assert_not @entry.settled?

    @entry.mark_as_settled!("settlement_123")
    assert @entry.settled?
    assert_equal "settlement_123", @entry.settlement_reference
  end

  test "should detect partner borrowing" do
    @entry.direction = :partner_owes_joint_account
    assert @entry.partner_borrowing?
    assert_not @entry.joint_account_borrowing?
  end

  test "should detect joint account borrowing" do
    @entry.direction = :joint_account_owes_partner
    assert @entry.joint_account_borrowing?
    assert_not @entry.partner_borrowing?
  end
end

