require "test_helper"

class SettlementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @couple = Couple.create!(name: "Test Couple", slug: "testcouple#{rand(10000)}", timezone: "UTC")
    @user = User.create!(
      email: "testuser@example.com",
      name: "Test User",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
    @partner = User.create!(
      email: "partner@example.com",
      name: "Partner User",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
    @couple.update!(default_currency: "EUR")
    @settlement = @couple.settlements.create!(
      payer: @user,
      payee: @partner,
      amount_cents: 5000,
      settled_on: Date.today,
      notes: "Test settlement"
    )
    sign_in @user
  end

  test "index action authenticated user can view settlements" do
    get settlements_path
    assert_response :success
    assert_not_nil assigns(:settlements)
  end

  test "index action settlements are ordered by date most recent first" do
    old_settlement = @couple.settlements.create!(
      payer: @user,
      payee: @partner,
      amount_cents: 3000,
      settled_on: Date.today - 5
    )

    new_settlement = @couple.settlements.create!(
      payer: @partner,
      payee: @user,
      amount_cents: 2000,
      settled_on: Date.today
    )

    get settlements_path
    assert_response :success

    settlements = assigns(:settlements)
    assert_equal new_settlement.id, settlements.first.id
  end

  test "index action date filtering works correctly" do
    old_settlement = @couple.settlements.create!(
      payer: @user,
      payee: @partner,
      amount_cents: 3000,
      settled_on: Date.today - 10
    )

    get settlements_path, params: { start_date: Date.today - 2, end_date: Date.today + 1 }
    assert_response :success

    settlements = assigns(:settlements)
    assert_not_includes settlements, old_settlement
    assert_includes settlements, @settlement
  end

  test "new action form is rendered with correct defaults" do
    get new_settlement_path
    assert_response :success
    assert_not_nil assigns(:settlement)
    assert_not_nil assigns(:couple_users)
    assert_not_nil assigns(:partner)
    assert_equal @user, assigns(:settlement).payer
    assert_equal Date.today, assigns(:settlement).settled_on
  end

  test "new action query parameters pre-fill the form" do
    get new_settlement_path, params: {
      payer_id: @partner.id,
      payee_id: @user.id,
      amount: "50.00"
    }

    assert_response :success
    settlement = assigns(:settlement)
    assert_equal @partner.id, settlement.payer_id
    assert_equal @user.id, settlement.payee_id
    assert_equal 50.0, settlement.amount_dollars
  end

  test "new action auto-selects partner when only payer is specified" do
    get new_settlement_path, params: { payer_id: @user.id }

    assert_response :success
    settlement = assigns(:settlement)
    assert_equal @user.id, settlement.payer_id
    assert_equal @partner.id, settlement.payee_id
  end

  test "new action auto-selects partner when only payee is specified" do
    get new_settlement_path, params: { payee_id: @partner.id }

    assert_response :success
    settlement = assigns(:settlement)
    assert_equal @user.id, settlement.payer_id
    assert_equal @partner.id, settlement.payee_id
  end

  test "create action valid settlement is created successfully" do
    assert_difference "Settlement.count", 1 do
      post settlements_path, params: {
        settlement: {
          payer_id: @user.id,
          payee_id: @partner.id,
          amount_dollars: 75.50,
          settled_on: Date.today,
          notes: "New settlement"
        }
      }
    end

    assert_redirected_to expenses_path
    assert_equal "Settlement recorded successfully.", flash[:notice]
  end

  test "create action amount_dollars is converted to amount_cents correctly" do
    post settlements_path, params: {
      settlement: {
        payer_id: @user.id,
        payee_id: @partner.id,
        amount_dollars: 123.45,
        settled_on: Date.today
      }
    }

    settlement = Settlement.last
    assert_equal 12345, settlement.amount_cents
  end

  test "create action activity log is created" do
    assert_difference "ActivityLog.count", 1 do
      post settlements_path, params: {
        settlement: {
          payer_id: @user.id,
          payee_id: @partner.id,
          amount_dollars: 50.00,
          settled_on: Date.today
        }
      }
    end

    activity = ActivityLog.last
    assert_includes activity.action, "recorded payment"
  end

  test "create action invalid settlement shows errors" do
    assert_no_difference "Settlement.count" do
      post settlements_path, params: {
        settlement: {
          payer_id: @user.id,
          payee_id: @partner.id,
          amount_dollars: nil,
          settled_on: Date.today
        }
      }
    end

    assert_response :unprocessable_entity
    assert_template :new
  end

  test "create action payer and payee must be different" do
    assert_no_difference "Settlement.count" do
      post settlements_path, params: {
        settlement: {
          payer_id: @user.id,
          payee_id: @user.id,
          amount_dollars: 50.00,
          settled_on: Date.today
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "create action payer must belong to couple" do
    other_couple = Couple.create!(name: "Other Couple", slug: "other#{rand(10000)}", timezone: "UTC")
    other_user = User.create!(
      email: "other@example.com",
      name: "Other User",
      password: "password123",
      password_confirmation: "password123",
      couple: other_couple
    )

    assert_no_difference "Settlement.count" do
      post settlements_path, params: {
        settlement: {
          payer_id: other_user.id,
          payee_id: @partner.id,
          amount_dollars: 50.00,
          settled_on: Date.today
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "edit action form is rendered with settlement data" do
    get edit_settlement_path(@settlement)
    assert_response :success
    assert_equal @settlement, assigns(:settlement)
    assert_not_nil assigns(:couple_users)
    assert_not_nil assigns(:partner)
  end

  test "update action valid update succeeds" do
    patch settlement_path(@settlement), params: {
      settlement: {
        amount_dollars: 100.00,
        notes: "Updated notes"
      }
    }

    assert_redirected_to expenses_path
    assert_equal "Settlement updated successfully.", flash[:notice]

    @settlement.reload
    assert_equal 10000, @settlement.amount_cents
    assert_equal "Updated notes", @settlement.notes
    assert_equal @couple.default_currency_symbol, @settlement.currency_symbol
  end

  test "update action activity log is created for update" do
    assert_difference "ActivityLog.count", 1 do
      patch settlement_path(@settlement), params: {
        settlement: {
          amount_dollars: 100.00
        }
      }
    end

    activity = ActivityLog.last
    assert_includes activity.action, "updated settlement"
  end

  test "update action invalid update shows errors" do
    patch settlement_path(@settlement), params: {
      settlement: {
        amount_dollars: nil
      }
    }

    assert_response :unprocessable_entity
    assert_template :edit
  end

  test "update action amount conversion works correctly" do
    patch settlement_path(@settlement), params: {
      settlement: {
        amount_dollars: 67.89
      }
    }

    @settlement.reload
    assert_equal 6789, @settlement.amount_cents
  end

  test "destroy action settlement is deleted" do
    assert_difference "Settlement.count", -1 do
      delete settlement_path(@settlement)
    end

    assert_redirected_to expenses_path
    assert_equal "Settlement was successfully deleted.", flash[:notice]
  end

  test "destroy action activity log is created for deletion" do
    assert_difference "ActivityLog.count", 1 do
      delete settlement_path(@settlement)
    end

    activity = ActivityLog.last
    assert_includes activity.action, "deleted settlement"
  end

  test "unauthenticated user is redirected" do
    sign_out @user

    get settlements_path
    assert_redirected_to new_user_session_path
  end

  test "user without couple is redirected to pairing" do
    user_without_couple = User.create!(
      email: "nocouple@example.com",
      name: "No Couple User",
      password: "password123",
      password_confirmation: "password123"
    )
    sign_in user_without_couple

    get settlements_path
    assert_redirected_to new_pairing_path
  end

  test "user cannot access other couple's settlements" do
    other_couple = Couple.create!(name: "Other Couple", slug: "other#{rand(10000)}", timezone: "UTC")
    other_user = User.create!(
      email: "other@example.com",
      name: "Other User",
      password: "password123",
      password_confirmation: "password123",
      couple: other_couple
    )
    other_partner = User.create!(
      email: "otherpartner@example.com",
      name: "Other Partner",
      password: "password123",
      password_confirmation: "password123",
      couple: other_couple
    )
    other_settlement = other_couple.settlements.create!(
      payer: other_user,
      payee: other_partner,
      amount_cents: 3000,
      settled_on: Date.today
    )

    sign_in @user

    get settlement_path(other_settlement)

    assert_redirected_to expenses_path
    assert_includes flash[:alert], "Settlement not found."
  end
end
