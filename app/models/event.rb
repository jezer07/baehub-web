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

  scope :future, -> { where("starts_at >= ?", Time.current.beginning_of_day) }
  scope :current_week, -> { where(starts_at: Time.current.beginning_of_week..Time.current.end_of_week) }
  scope :by_category, ->(category) { where(category: category) if category.present? }
  scope :between_dates, ->(start_date, end_date) { where(starts_at: start_date.beginning_of_day..end_date.end_of_day) if start_date.present? && end_date.present? }
  scope :upcoming, -> { where("starts_at >= ?", Time.current).order(starts_at: :asc) }
  scope :past, -> { where("starts_at < ?", Time.current).order(starts_at: :desc) }
  scope :all_day_events, -> { where(all_day: true) }
  scope :timed_events, -> { where(all_day: false) }

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

  private

  def ends_after_start
    return if ends_at.blank? || starts_at.blank?
    return if ends_at >= starts_at

    errors.add(:ends_at, "must occur after the start time")
  end
end
