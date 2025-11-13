require "test_helper"

class JointAccounts::CreatorTest < ActiveSupport::TestCase
  def setup
    @couple = couples(:one)
    @user = users(:one)
  end

  test "should create joint account successfully" do
    params = {
      name: "Vacation Fund",
      currency: "USD",
      member_ids: [@user.id]
    }

    result = JointAccounts::Creator.new(
      couple: @couple,
      creator_user: @user,
      params: params
    ).call

    assert result[:success]
    assert_instance_of JointAccount, result[:joint_account]
    assert_equal "Vacation Fund", result[:joint_account].name
    assert_equal "USD", result[:joint_account].currency
  end

  test "should fail without couple" do
    result = JointAccounts::Creator.new(
      couple: nil,
      creator_user: @user,
      params: { name: "Test" }
    ).call

    assert_not result[:success]
    assert_includes result[:errors].join, "Couple is required"
  end

  test "should fail without name" do
    result = JointAccounts::Creator.new(
      couple: @couple,
      creator_user: @user,
      params: {}
    ).call

    assert_not result[:success]
    assert_includes result[:errors].join, "Name is required"
  end

  test "should create memberships for members" do
    params = {
      name: "Test Account",
      currency: "USD",
      member_ids: [@user.id]
    }

    result = JointAccounts::Creator.new(
      couple: @couple,
      creator_user: @user,
      params: params
    ).call

    assert result[:success]
    assert_equal 1, result[:joint_account].joint_account_memberships.count
  end

  test "should initialize balances for members" do
    params = {
      name: "Test Account",
      currency: "USD",
      member_ids: [@user.id]
    }

    result = JointAccounts::Creator.new(
      couple: @couple,
      creator_user: @user,
      params: params
    ).call

    assert result[:success]
    assert_equal 1, result[:joint_account].joint_account_balances.count
  end
end

