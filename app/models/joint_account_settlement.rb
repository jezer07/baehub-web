class JointAccountSettlement < ApplicationRecord
  belongs_to :joint_account
  belongs_to :settled_by, class_name: "User", foreign_key: :settled_by_id

  has_many :joint_account_settlement_entries, dependent: :destroy
  has_many :joint_account_ledger_entries, through: :joint_account_settlement_entries

  serialize :metadata, coder: JSON

  validates :total_amount_cents, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :currency, presence: true, length: { is: 3 }, inclusion: { in: CurrencyCatalog.codes }
  validates :settlement_date, presence: true

  before_validation :normalize_currency
  before_validation :set_settlement_date
  before_validation :ensure_metadata

  scope :for_joint_account, ->(joint_account_id) { where(joint_account_id: joint_account_id) }
  scope :recent, -> { order(settlement_date: :desc, created_at: :desc) }

  def currency_symbol
    CurrencyCatalog.symbol_for(currency)
  end

  def ledger_entries_count
    joint_account_ledger_entries.count
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

  def set_settlement_date
    self.settlement_date ||= Date.current
  end

  def ensure_metadata
    self.metadata ||= {}
  end
end

