class Event < ApplicationRecord
  belongs_to :couple
  belongs_to :creator, class_name: "User"

  has_many :event_responses, dependent: :destroy
  has_many :reminders, as: :remindable, dependent: :destroy
  has_many :activity_logs, as: :subject, dependent: :destroy

  validates :title, presence: true, length: { maximum: 140 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :starts_at, presence: true
  validate :ends_after_start
  validate :valid_recurrence_rule_format

  scope :future, -> { where("starts_at >= ?", Time.current.beginning_of_day) }
  scope :current_week, -> { where(starts_at: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :between_dates, ->(start_date, end_date) { where(starts_at: start_date.beginning_of_day..end_date.end_of_day) if start_date.present? && end_date.present? }
  scope :upcoming, -> { where("starts_at >= ?", Time.current).order(starts_at: :asc) }
  scope :past, -> { where("starts_at < ?", Time.current).order(starts_at: :desc) }
  scope :all_day_events, -> { where(all_day: true) }
  scope :timed_events, -> { where(all_day: false) }
  scope :recurring, -> { where.not(recurrence_rule: nil) }
  scope :non_recurring, -> { where(recurrence_rule: nil) }

  def duration_in_hours
    return nil if ends_at.blank?

    ((ends_at - starts_at) / 1.hour).round(2)
  end

  def single_day_event?
    return true if ends_at.blank?

    starts_at.to_date == ends_at.to_date
  end

  def in_progress?
    return false if ends_at.blank?

    current_time = Time.current
    current_time >= starts_at && current_time <= ends_at
  end

  def formatted_date_range(timezone = "UTC")
    tz = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
    start_time = starts_at.in_time_zone(tz)
    end_time = ends_at&.in_time_zone(tz)

    if all_day?
      if single_day_event?
        start_time.strftime("%B %-d, %Y")
      elsif end_time.present?
        "#{start_time.strftime('%B %-d')} - #{end_time.strftime('%B %-d, %Y')}"
      else
        start_time.strftime("%B %-d, %Y")
      end
    else
      if single_day_event?
        if end_time.present?
          "#{start_time.strftime('%B %-d, %Y at %-I:%M %p')} - #{end_time.strftime('%-I:%M %p')}"
        else
          start_time.strftime("%B %-d, %Y at %-I:%M %p")
        end
      elsif end_time.present?
        "#{start_time.strftime('%B %-d, %-I:%M %p')} - #{end_time.strftime('%B %-d, %-I:%M %p')}"
      else
        start_time.strftime("%B %-d, %-I:%M %p")
      end
    end
  end

  def recurring?
    recurrence_rule.present?
  end

  def parse_recurrence_rule
    return nil if recurrence_rule.blank?

    parts = recurrence_rule.split(":")
    return nil unless parts.size == 3

    {
      frequency: parts[0],
      interval: parts[1].to_i,
      end_date: parts[2]
    }
  end

  def recurrence_end_date
    parsed = parse_recurrence_rule
    return nil if parsed.nil? || parsed[:end_date] == "never"

    Date.parse(parsed[:end_date])
  rescue ArgumentError
    nil
  end

  def generate_occurrences(start_date, end_date, limit: 100)
    return [] unless recurring?

    parsed = parse_recurrence_rule
    return [] if parsed.nil?

    occurrences = []
    current_date = starts_at.to_date
    frequency = parsed[:frequency]
    interval = parsed[:interval]
    rule_end_date = recurrence_end_date

    while occurrences.size < limit && current_date <= end_date
      if current_date >= start_date
        occurrences << current_date
      end

      break if rule_end_date.present? && current_date >= rule_end_date

      case frequency
      when "daily"
        current_date += interval.days
      when "weekly"
        current_date += (interval * 7).days
      when "monthly"
        current_date = current_date.next_month(interval)
      when "yearly"
        current_date = current_date.next_year(interval)
      else
        break
      end
    end

    occurrences
  end

  def next_occurrence(from_date = Date.today)
    return nil unless recurring?

    parsed = parse_recurrence_rule
    return nil if parsed.nil?

    current_date = starts_at.to_date
    frequency = parsed[:frequency]
    interval = parsed[:interval]
    rule_end_date = recurrence_end_date

    while current_date <= (from_date + 5.years)
      if current_date > from_date
        return current_date if rule_end_date.nil? || current_date <= rule_end_date
        return nil
      end

      case frequency
      when "daily"
        current_date += interval.days
      when "weekly"
        current_date += (interval * 7).days
      when "monthly"
        current_date = current_date.next_month(interval)
      when "yearly"
        current_date = current_date.next_year(interval)
      else
        break
      end
    end

    nil
  end

  def recurrence_summary
    return "" unless recurring?

    parsed = parse_recurrence_rule
    return "" if parsed.nil?

    frequency = parsed[:frequency]
    interval = parsed[:interval]
    end_date = parsed[:end_date]

    frequency_text = case frequency
    when "daily"
      interval == 1 ? "Every day" : "Every #{interval} days"
    when "weekly"
      interval == 1 ? "Every week" : "Every #{interval} weeks"
    when "monthly"
      interval == 1 ? "Every month" : "Every #{interval} months"
    when "yearly"
      interval == 1 ? "Every year" : "Every #{interval} years"
    else
      "Unknown frequency"
    end

    if end_date != "never"
      begin
        formatted_end_date = Date.parse(end_date).strftime("%b %d, %Y")
        "#{frequency_text} until #{formatted_end_date}"
      rescue ArgumentError
        frequency_text
      end
    else
      frequency_text
    end
  end

  private

  def ends_after_start
    return if ends_at.blank? || starts_at.blank?
    return if ends_at >= starts_at

    errors.add(:ends_at, "must occur after the start time")
  end

  def valid_recurrence_rule_format
    return if recurrence_rule.blank?

    parts = recurrence_rule.split(":")
    unless parts.size == 3
      errors.add(:recurrence_rule, "must be in format 'frequency:interval:end_date'")
      return
    end

    frequency = parts[0]
    interval = parts[1]
    end_date = parts[2]

    valid_frequencies = [ "daily", "weekly", "monthly", "yearly" ]
    unless valid_frequencies.include?(frequency)
      errors.add(:recurrence_rule, "frequency must be one of: #{valid_frequencies.join(', ')}")
    end

    unless interval.match?(/\A\d+\z/) && interval.to_i > 0
      errors.add(:recurrence_rule, "interval must be a positive integer")
    end

    unless end_date == "never" || valid_date?(end_date)
      errors.add(:recurrence_rule, "end date must be 'never' or a valid date")
    end
  end

  def valid_date?(date_string)
    Date.parse(date_string)
    true
  rescue ArgumentError
    false
  end
end
