class EventResponse < ApplicationRecord
  belongs_to :event
  belongs_to :user

  has_many :activity_logs, as: :subject, dependent: :destroy

  enum :status, { pending: "pending", accepted: "accepted", declined: "declined" }, default: :pending, validate: true

  validates :event, uniqueness: { scope: :user_id }
  validate :user_is_not_creator
  validate :user_in_same_couple

  before_save :set_responded_at_on_status_change

  scope :pending, -> { where(status: :pending) }
  scope :accepted, -> { where(status: :accepted) }
  scope :declined, -> { where(status: :declined) }
  scope :responded, -> { where.not(status: :pending) }

  def status_badge_class
    case status
    when "pending"
      "bg-yellow-50 text-yellow-700 border-yellow-200"
    when "accepted"
      "bg-success-50 text-success-700 border-success-200"
    when "declined"
      "bg-gray-50 text-gray-700 border-gray-200"
    else
      "bg-neutral-50 text-neutral-700 border-neutral-200"
    end
  end

  def status_icon
    case status
    when "accepted"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>'
    when "declined"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>'
    when "pending"
      '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'
    else
      ""
    end
  end

  private

  def user_is_not_creator
    return if event.blank? || user.blank?

    if user_id == event.creator_id
      errors.add(:user, "cannot respond to your own event")
    end
  end

  def user_in_same_couple
    return if event.blank? || user.blank?

    if user.couple_id != event.couple_id
      errors.add(:user, "must belong to the same couple as the event")
    end
  end

  def set_responded_at_on_status_change
    if will_save_change_to_status? && !pending?
      self.responded_at = Time.current
    elsif will_save_change_to_status? && pending?
      self.responded_at = nil
    end
  end
end
