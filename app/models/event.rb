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

  private

  def ends_after_start
    return if ends_at.blank? || starts_at.blank?
    return if ends_at >= starts_at

    errors.add(:ends_at, "must occur after the start time")
  end
end
