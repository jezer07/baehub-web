require "test_helper"

class JointAccountTest < ActiveSupport::TestCase
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
  end

  test "should be valid with valid attributes" do
    assert @joint_account.valid?
  end

  test "should require name" do
    @joint_account.name = nil
    assert_not @joint_account.valid?
    assert_includes @joint_account.errors[:name], "can't be blank"
  end

  test "should require currency" do
    @joint_account.currency = nil
    assert_not @joint_account.valid?
  end

  test "should have default status of active" do
    new_account = JointAccount.new(
      couple: @couple,
      created_by: @user,
      name: "New Account"
    )
    assert_equal "active", new_account.status
  end

  test "should return currency symbol" do
    assert_equal "$", @joint_account.currency_symbol
  end

  test "should check if user is member" do
    membership = @joint_account.joint_account_memberships.create!(
      user: @user,
      active: true
    )

    assert @joint_account.member?(@user)
  end

  test "should return active members" do
    membership = @joint_account.joint_account_memberships.create!(
      user: @user,
      active: true
    )

    assert_equal 1, @joint_account.active_members.count
  end
end

