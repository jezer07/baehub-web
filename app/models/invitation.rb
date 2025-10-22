class Invitation < ApplicationRecord
  CODE_LENGTH = 8

  belongs_to :couple, optional: true
  belongs_to :sender, class_name: "User"
  has_many :activity_logs, as: :subject, dependent: :destroy

  enum :status, { pending: "pending", redeemed: "redeemed", revoked: "revoked", expired: "expired" }, validate: true

  validates :code, presence: true, uniqueness: true, length: { is: CODE_LENGTH }
  validates :expires_at, presence: true
  validates :recipient_email, allow_blank: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  before_validation :assign_code, on: :create
  before_validation :assign_expiry, on: :create
  before_save :expire_if_needed

  scope :active, -> { pending.where("expires_at > ?", Time.current).where(revoked_at: nil) }

  def redeem!
    return false unless pending?
    return false if expires_at <= Time.current

    update(status: :redeemed, redeemed_at: Time.current)
  end

  private

  def assign_code
    return if code.present?

    loop do
      self.code = SecureRandom.alphanumeric(CODE_LENGTH).upcase
      break unless self.class.exists?(code:)
    end
  end

  def assign_expiry
    self.expires_at ||= 7.days.from_now
  end

  def expire_if_needed
    return unless pending?
    return unless expires_at.present? && expires_at <= Time.current

    self.status = :expired
  end
end
