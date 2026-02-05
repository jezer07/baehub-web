require "test_helper"

class EventOccurrenceBuilderTest < ActiveSupport::TestCase
  setup do
    @couple = couples(:one)
    @user = users(:one)
  end

  test "includes non-recurring events that overlap the window" do
    event = Event.create!(
      couple: @couple,
      creator: @user,
      title: "Dinner",
      description: "",
      starts_at: Time.zone.parse("2024-11-10 18:00"),
      ends_at: Time.zone.parse("2024-11-10 20:00"),
      all_day: false
    )

    occurrences = EventOccurrenceBuilder.expand(
      [ event ],
      range_start: Date.new(2024, 11, 1),
      range_end: Date.new(2024, 11, 30)
    )

    assert_equal 1, occurrences.size
    assert_equal event.starts_at, occurrences.first.starts_at
    assert_equal event.ends_at, occurrences.first.ends_at
  end

  test "expands recurring events across the provided range" do
    event = Event.create!(
      couple: @couple,
      creator: @user,
      title: "Workout",
      description: "",
      starts_at: Time.zone.parse("2024-11-01 07:00"),
      ends_at: Time.zone.parse("2024-11-01 08:00"),
      all_day: false,
      recurrence_rule: "weekly:1:never"
    )

    occurrences = EventOccurrenceBuilder.expand(
      [ event ],
      range_start: Date.new(2024, 11, 1),
      range_end: Date.new(2024, 11, 29),
      per_event_limit: 10
    )

    assert_equal 5, occurrences.size
    assert_equal Time.zone.parse("2024-11-15 07:00"), occurrences.third.starts_at
  end
end
