class JointAccountLedgerEntry < ApplicationRecord
  belongs_to :joint_account
  belongs_to :initiator, class_name: "User", foreign_key: :initiator_id
  belongs_to :counterparty, class_name: "User", foreign_key: :counterparty_id, optional: true

  has_many :joint_account_settlement_entries, dependent: :restrict_with_exception
  has_many :joint_account_settlements, through: :joint_account_settlement_entries

  serialize :metadata, coder: JSON

  enum :direction, {
    partner_owes_joint_account: "partner_owes_joint_account",
    joint_account_owes_partner: "joint_account_owes_partner"
  }, validate: true

  validates :amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, length: { is: 3 }, inclusion: { in: CurrencyCatalog.codes }
  validates :direction, presence: true
  validate :amount_within_configured_limits

  before_validation :normalize_currency
  before_validation :ensure_metadata

  scope :unsettled, -> { where(settled_at: nil) }
  scope :settled, -> { where.not(settled_at: nil) }
  scope :for_joint_account, ->(joint_account_id) { where(joint_account_id: joint_account_id) }
  scope :for_user, ->(user_id) { where("initiator_id = ? OR counterparty_id = ?", user_id, user_id) }
  scope :by_direction, ->(direction) { where(direction: direction) }
  scope :recent, -> { order(created_at: :desc) }

  def currency_symbol
    CurrencyCatalog.symbol_for(currency)
  end

  def settled?
    settled_at.present?
  end

  def mark_as_settled!(settlement_ref = nil)
    update!(
      settled_at: Time.current,
      settlement_reference: settlement_ref
    )
  end

  def partner_borrowing?
    direction == "partner_owes_joint_account"
  end

  def joint_account_borrowing?
    direction == "joint_account_owes_partner"
  end

  private

  def normalize_currency
    normalized = currency.to_s.upcase

    if normalized.blank?
      self.currency = joint_account&.currency || CurrencyCatalog.default_code
    elsif CurrencyCatalog.codes.include?(normalized)
      self.currency = normalized
    end
  end

  def ensure_metadata
    self.metadata ||= {}
  end

  def amount_within_configured_limits
    return unless joint_account && amount_cents

    max_transaction = joint_account.settings.dig("max_transaction_cents")
    return unless max_transaction

    if amount_cents > max_transaction
      errors.add(:amount_cents, "exceeds maximum transaction limit")
    end
  end
end

