class EventResponse < ApplicationRecord
  belongs_to :event
  belongs_to :user

  enum :status, { pending: "pending", accepted: "accepted", declined: "declined" }, default: :pending, validate: true

  validates :event, uniqueness: { scope: :user_id }
end
