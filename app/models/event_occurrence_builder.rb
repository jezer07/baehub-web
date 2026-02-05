class EventOccurrenceBuilder
  DEFAULT_LIMIT = 120

  def self.expand(events, range_start:, range_end:, per_event_limit: DEFAULT_LIMIT)
    return [] if events.blank? || range_start.blank? || range_end.blank?

    start_date = range_start.to_date
    end_date = range_end.to_date

    events.flat_map do |event|
      occurrences_for_event(event, start_date:, end_date:, limit: per_event_limit)
    end
  end

  def self.occurrences_for_event(event, start_date:, end_date:, limit:)
    return [] if end_date < start_date

    if event.recurring?
      build_recurring_occurrences(event, start_date:, end_date:, limit:)
    else
      overlaps_range = event_overlaps_range?(event, start_date:, end_date:)

      if overlaps_range
        [ EventOccurrence.new(event, starts_at: event.starts_at, ends_at: event.ends_at) ]
      else
        []
      end
    end
  end
  private_class_method :occurrences_for_event

  def self.build_recurring_occurrences(event, start_date:, end_date:, limit:)
    occurrence_dates = event.generate_occurrences(start_date, end_date, limit:)

    occurrence_dates.map do |date|
      offset_days = (date - event.starts_at.to_date).to_i
      occurrence_start = event.starts_at + offset_days.days
      occurrence_end = event.ends_at ? event.ends_at + offset_days.days : nil

      EventOccurrence.new(event, starts_at: occurrence_start, ends_at: occurrence_end)
    end
  end
  private_class_method :build_recurring_occurrences

  def self.event_overlaps_range?(event, start_date:, end_date:)
    event_start = event.starts_at.to_date
    event_end = (event.ends_at || event.starts_at).to_date

    event_start <= end_date && event_end >= start_date
  end
  private_class_method :event_overlaps_range?
end
