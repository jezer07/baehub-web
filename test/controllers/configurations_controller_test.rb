require "test_helper"

class ConfigurationsControllerTest < ActionDispatch::IntegrationTest
  test "ios_v1 returns JSON with rules array" do
    get "/configurations/ios_v1"

    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("rules"), "Expected JSON to contain 'rules' key"
    assert_kind_of Array, body["rules"]
    assert body["rules"].length >= 2, "Expected at least 2 rules"

    body["rules"].each do |rule|
      assert rule.key?("patterns"), "Each rule must have 'patterns'"
      assert rule.key?("properties"), "Each rule must have 'properties'"
    end
  end

  test "android_v1 returns JSON with rules array and uri properties" do
    get "/configurations/android_v1"

    assert_response :success
    body = JSON.parse(response.body)
    assert body.key?("rules"), "Expected JSON to contain 'rules' key"
    assert_kind_of Array, body["rules"]
    assert body["rules"].length >= 2, "Expected at least 2 rules"

    body["rules"].each do |rule|
      assert rule.key?("patterns"), "Each rule must have 'patterns'"
      assert rule.key?("properties"), "Each rule must have 'properties'"
      assert rule["properties"].key?("uri"), "Android rules must include 'uri' property"
    end
  end

  test "ios_v1 is accessible without authentication" do
    get "/configurations/ios_v1"
    assert_response :success
  end

  test "android_v1 is accessible without authentication" do
    get "/configurations/android_v1"
    assert_response :success
  end
end
