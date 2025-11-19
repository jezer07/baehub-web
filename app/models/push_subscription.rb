class PushSubscription < ApplicationRecord
  belongs_to :user

  validates :endpoint, presence: true, uniqueness: true
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true

  scope :for_couple, ->(couple_id) { joins(:user).where(users: { couple_id: couple_id }) }
end
