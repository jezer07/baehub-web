require "time"

module GoogleCalendar
  class EventMapper
    def self.to_google_event(event, timezone:)
      payload = {
        summary: event.title,
        description: event.description
      }

      if event.all_day?
        start_date = event.starts_at.in_time_zone(timezone).to_date
        end_date = if event.ends_at.present?
          event.ends_at.in_time_zone(timezone).to_date + 1.day
        else
          start_date + 1.day
        end
        payload[:start] = { date: start_date.to_s }
        payload[:end] = { date: end_date.to_s }
      else
        start_time = event.starts_at.in_time_zone(timezone)
        end_time = event.ends_at.present? ? event.ends_at.in_time_zone(timezone) : start_time + 1.hour
        payload[:start] = { dateTime: start_time.iso8601, timeZone: timezone }
        payload[:end] = { dateTime: end_time.iso8601, timeZone: timezone }
      end

      recurrence = Recurrence.to_google_rrule(event, timezone: timezone)
      payload[:recurrence] = recurrence if recurrence.present?

      payload
    end

    def self.from_google_event(item, timezone:)
      summary = item["summary"].presence || "Untitled event"
      description = item["description"]

      if item.dig("start", "date").present?
        all_day = true
        start_date = Date.parse(item.dig("start", "date"))
        end_date = Date.parse(item.dig("end", "date")) - 1.day
        starts_at = start_date.in_time_zone(timezone).beginning_of_day
        ends_at = end_date.in_time_zone(timezone).end_of_day
      else
        all_day = false
        starts_at = Time.iso8601(item.dig("start", "dateTime"))
        ends_at = item.dig("end", "dateTime").present? ? Time.iso8601(item.dig("end", "dateTime")) : nil
      end

      recurrence_rule = Recurrence.from_google_rrule(item["recurrence"], starts_at: starts_at, timezone: timezone)

      {
        title: summary,
        description: description,
        starts_at: starts_at,
        ends_at: ends_at,
        all_day: all_day,
        recurrence_rule: recurrence_rule
      }
    end
  end
end
