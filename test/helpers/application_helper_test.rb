require "test_helper"

class ApplicationHelperTest < ActiveSupport::TestCase
  include ApplicationHelper
  
  self.use_transactional_tests = false
  
  def setup
  end

  test "contrasting_text_color returns black for light backgrounds" do
    assert_equal "#000000", contrasting_text_color("#ffffff")
    assert_equal "#000000", contrasting_text_color("#ffff00")
    assert_equal "#000000", contrasting_text_color("#00ff00")
    assert_equal "#000000", contrasting_text_color("#e5e7eb")
    assert_equal "#000000", contrasting_text_color("#f0f0f0")
  end

  test "contrasting_text_color returns white for dark backgrounds" do
    assert_equal "#ffffff", contrasting_text_color("#000000")
    assert_equal "#ffffff", contrasting_text_color("#0000ff")
    assert_equal "#ffffff", contrasting_text_color("#ff0000")
    assert_equal "#ffffff", contrasting_text_color("#1a1a1a")
    assert_equal "#ffffff", contrasting_text_color("#333333")
  end

  test "contrasting_text_color handles rgb format" do
    assert_equal "#000000", contrasting_text_color("rgb(255, 255, 255)")
    assert_equal "#ffffff", contrasting_text_color("rgb(0, 0, 0)")
    assert_equal "#000000", contrasting_text_color("rgb(255, 255, 0)")
    assert_equal "#ffffff", contrasting_text_color("rgb(255, 0, 0)")
  end

  test "contrasting_text_color handles rgba format" do
    assert_equal "#000000", contrasting_text_color("rgba(255, 255, 255, 1)")
    assert_equal "#ffffff", contrasting_text_color("rgba(0, 0, 0, 0.5)")
    assert_equal "#000000", contrasting_text_color("rgba(255, 255, 0, 0.8)")
  end

  test "contrasting_text_color returns fallback for invalid colors" do
    assert_equal "#111111", contrasting_text_color("")
    assert_equal "#111111", contrasting_text_color(nil)
    assert_equal "#111111", contrasting_text_color("invalid")
    assert_equal "#111111", contrasting_text_color("blue")
  end

  test "safe_event_color returns event color when valid" do
    event = Event.new(color: "#ff0000")
    assert_equal "#ff0000", safe_event_color(event)
  end

  test "safe_event_color returns fallback when color is blank" do
    event = Event.new(color: nil)
    assert_equal "#e5e7eb", safe_event_color(event)

    event = Event.new(color: "")
    assert_equal "#e5e7eb", safe_event_color(event)
  end

  test "safe_event_color returns fallback for invalid colors" do
    event = Event.new(color: "invalid")
    assert_equal "#e5e7eb", safe_event_color(event)

    event = Event.new(color: "blue")
    assert_equal "#e5e7eb", safe_event_color(event)
  end
end

