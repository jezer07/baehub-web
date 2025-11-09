# app/models/api_token.rb
class ApiToken < ApplicationRecord
  belongs_to :user

  before_create :generate_token
  before_create :set_expiration

  # Scopes
  scope :active, -> { where("expires_at > ?", Time.current) }
  scope :expired, -> { where("expires_at <= ?", Time.current) }

  # Validations
  validates :token, presence: true, uniqueness: true

  # Constants
  TOKEN_EXPIRATION = 30.days

  def active?
    expires_at.nil? || expires_at > Time.current
  end

  def expired?
    !active?
  end

  def touch_last_used!
    update_column(:last_used_at, Time.current)
  end

  private

  def generate_token
    self.token = SecureRandom.hex(32)
  end

  def set_expiration
    self.expires_at = TOKEN_EXPIRATION.from_now
  end
end
