require "test_helper"

class JointAccountsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @couple = couples(:one)
    @user = users(:one)
    @user.update!(couple: @couple)
    sign_in @user

    @joint_account = JointAccount.create!(
      couple: @couple,
      created_by: @user,
      name: "Test Account",
      currency: "USD"
    )
    @joint_account.joint_account_memberships.create!(
      user: @user,
      active: true
    )
  end

  test "should get index" do
    get joint_accounts_path
    assert_response :success
  end

  test "should get show" do
    get joint_account_path(@joint_account)
    assert_response :success
  end

  test "should get new" do
    get new_joint_account_path
    assert_response :success
  end

  test "should create joint account" do
    assert_difference("JointAccount.count") do
      post joint_accounts_path, params: {
        joint_account: {
          name: "New Account",
          currency: "USD",
          member_ids: [@user.id]
        }
      }
    end

    assert_redirected_to joint_account_path(JointAccount.last)
  end

  test "should get edit" do
    get edit_joint_account_path(@joint_account)
    assert_response :success
  end

  test "should update joint account" do
    patch joint_account_path(@joint_account), params: {
      joint_account: {
        name: "Updated Name"
      }
    }

    assert_redirected_to joint_account_path(@joint_account)
    @joint_account.reload
    assert_equal "Updated Name", @joint_account.name
  end

  test "should archive joint account" do
    delete joint_account_path(@joint_account)
    
    @joint_account.reload
    assert_equal "archived", @joint_account.status
  end

  test "should get ledger" do
    get ledger_joint_account_path(@joint_account)
    assert_response :success
  end

  test "should get balances" do
    get balances_joint_account_path(@joint_account)
    assert_response :success
  end
end

