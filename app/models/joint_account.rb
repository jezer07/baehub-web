class JointAccount < ApplicationRecord
  belongs_to :couple
  belongs_to :created_by, class_name: "User", foreign_key: :created_by_id

  has_many :joint_account_memberships, dependent: :destroy
  has_many :users, through: :joint_account_memberships
  has_many :joint_account_ledger_entries, dependent: :destroy
  has_many :joint_account_settlements, dependent: :destroy
  has_many :joint_account_balances, dependent: :destroy

  serialize :settings, coder: JSON

  enum :status, {
    active: "active",
    inactive: "inactive",
    archived: "archived"
  }, default: :active, validate: true

  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :currency, presence: true, length: { is: 3 }, inclusion: { in: CurrencyCatalog.codes }

  before_validation :normalize_currency
  before_validation :ensure_settings

  scope :active_accounts, -> { where(status: :active) }
  scope :for_couple, ->(couple_id) { where(couple_id: couple_id) }

  def currency_symbol
    CurrencyCatalog.symbol_for(currency)
  end

  def active_members
    joint_account_memberships.where(active: true).includes(:user)
  end

  def member?(user)
    joint_account_memberships.exists?(user_id: user.id, active: true)
  end

  def outstanding_balance_for(user)
    joint_account_balances.find_by(user: user)&.balance_cents || 0
  end

  def total_outstanding_balance
    joint_account_balances.sum(:balance_cents)
  end

  private

  def normalize_currency
    normalized = currency.to_s.upcase

    if normalized.blank?
      self.currency = couple&.default_currency || CurrencyCatalog.default_code
    elsif CurrencyCatalog.codes.include?(normalized)
      self.currency = normalized
    end
  end

  def ensure_settings
    self.settings ||= {}
  end
end

