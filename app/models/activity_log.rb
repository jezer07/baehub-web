class ActivityLog < ApplicationRecord
  belongs_to :couple
  belongs_to :user, optional: true
  belongs_to :subject, polymorphic: true, optional: true

  validates :action, presence: true, length: { maximum: 120 }
  validates :metadata, presence: true

  scope :recent, -> { order(created_at: :desc).limit(20) }
end
