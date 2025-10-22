class Reminder < ApplicationRecord
  CHANNELS = %w[push email sms].freeze
  STATUSES = %w[scheduled sent canceled missed].freeze

  belongs_to :couple
  belongs_to :sender, class_name: "User", optional: true
  belongs_to :recipient, class_name: "User", optional: true
  belongs_to :remindable, polymorphic: true

  validates :channel, inclusion: { in: CHANNELS }
  validates :status, inclusion: { in: STATUSES }
  validates :deliver_at, presence: true
  validate :recipient_in_couple

  scope :pending_delivery, -> { where(status: "scheduled").where("deliver_at <= ?", Time.current) }

  private

  def recipient_in_couple
    return if recipient.blank? || couple.blank?
    return if recipient.couple_id == couple_id

    errors.add(:recipient_id, "must belong to the same couple")
  end
end
