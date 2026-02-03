module GoogleCalendar
  class Recurrence
    WEEKDAYS = {
      "sunday" => "SU",
      "monday" => "MO",
      "tuesday" => "TU",
      "wednesday" => "WE",
      "thursday" => "TH",
      "friday" => "FR",
      "saturday" => "SA"
    }.freeze

    def self.to_google_rrule(event, timezone:)
      return [] unless event.recurring?

      parsed = event.parse_recurrence_rule
      return [] if parsed.nil?

      freq = parsed[:frequency].to_s.upcase
      interval = parsed[:interval].to_i

      rule = "RRULE:FREQ=#{freq};INTERVAL=#{interval}"

      if parsed[:end_date].present? && parsed[:end_date] != "never"
        end_date = Date.parse(parsed[:end_date])
        rule += ";UNTIL=#{end_date.strftime('%Y%m%d')}"
      end

      start_time = event.starts_at.in_time_zone(timezone)
      case freq
      when "WEEKLY"
        rule += ";BYDAY=#{weekday_code(start_time)}"
      when "MONTHLY"
        rule += ";BYMONTHDAY=#{start_time.day}"
      when "YEARLY"
        rule += ";BYMONTH=#{start_time.month};BYMONTHDAY=#{start_time.day}"
      end

      [rule]
    rescue ArgumentError
      []
    end

    def self.from_google_rrule(recurrence_rules, starts_at:, timezone:)
      return nil if recurrence_rules.blank?

      rrule = Array(recurrence_rules).find { |rule| rule.to_s.start_with?("RRULE:") }
      return nil if rrule.blank?

      parts = rrule.delete_prefix("RRULE:").split(";").each_with_object({}) do |pair, memo|
        key, value = pair.split("=")
        memo[key] = value
      end

      frequency = parts["FREQ"]&.downcase
      return nil if frequency.blank?

      interval = parts["INTERVAL"].to_i
      interval = 1 if interval <= 0

      end_date = "never"
      if parts["UNTIL"].present?
        parsed_until = parse_until(parts["UNTIL"], timezone)
        end_date = parsed_until&.to_date&.to_s if parsed_until
      end

      start_time = starts_at.in_time_zone(timezone)

      if parts["BYDAY"].present?
        expected = weekday_code(start_time)
        byday = parts["BYDAY"].split(",").map(&:strip)
        return nil unless byday == [ expected ]
      end

      if parts["BYMONTHDAY"].present? && parts["BYMONTHDAY"].to_i != start_time.day
        return nil
      end

      if parts["BYMONTH"].present? && parts["BYMONTH"].to_i != start_time.month
        return nil
      end

      "#{frequency}:#{interval}:#{end_date}"
    rescue ArgumentError
      nil
    end

    def self.weekday_code(time)
      WEEKDAYS.fetch(time.strftime("%A").downcase)
    end

    def self.parse_until(value, timezone)
      tz = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
      if value.match?(/T/)
        tz.parse(value)
      else
        Date.parse(value).in_time_zone(tz)
      end
    end
  end
end
