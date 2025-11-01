require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @couple = Couple.create!(name: "Example Couple", slug: "example#{rand(10000)}", timezone: "UTC")
    @user = User.create!(
      email: "settings-user@example.com",
      name: "Settings User",
      password: "password123",
      password_confirmation: "password123",
      couple: @couple
    )
    sign_in @user
  end

  test "show renders successfully for coupled user" do
    get settings_path

    assert_response :success
    assert_equal @couple, assigns(:couple)
    assert_equal @user, assigns(:user)
  end

  test "update persists couple currency and user appearance preferences" do
    patch settings_path, params: {
      settings: {
        couple: { default_currency: "GBP" },
        user: { prefers_dark_mode: "1" }
      }
    }

    assert_redirected_to settings_path
    assert_equal "Settings updated successfully.", flash[:notice]
    follow_redirect!
    assert_response :success
    assert_equal "GBP", @couple.reload.default_currency
    assert @user.reload.prefers_dark_mode
  end

  test "redirects users without a couple" do
    sign_out @user

    solo_user = User.create!(
      email: "solo-settings@example.com",
      name: "Solo User",
      password: "password123",
      password_confirmation: "password123"
    )

    sign_in solo_user

    get settings_path

    assert_redirected_to new_pairing_path
    assert_equal "Create your shared space before updating settings.", flash[:alert]
    follow_redirect!
    assert_match "Create your shared space", response.body
  end
end
