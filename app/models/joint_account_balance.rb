class JointAccountBalance < ApplicationRecord
  belongs_to :joint_account
  belongs_to :user

  validates :currency, presence: true, length: { is: 3 }, inclusion: { in: CurrencyCatalog.codes }
  validates :balance_cents, presence: true, numericality: { only_integer: true }
  validates :borrowed_from_account_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :lent_to_account_cents, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :last_calculated_at, presence: true
  validates :user_id, uniqueness: { scope: [:joint_account_id, :currency], message: "already has a balance for this joint account and currency" }

  before_validation :set_last_calculated_at, on: :create

  scope :for_joint_account, ->(joint_account_id) { where(joint_account_id: joint_account_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }
  scope :positive_balances, -> { where("balance_cents > 0") }
  scope :negative_balances, -> { where("balance_cents < 0") }
  scope :by_currency, ->(currency) { where(currency: currency) }

  def currency_symbol
    CurrencyCatalog.symbol_for(currency)
  end

  def owes_to_joint_account?
    balance_cents < 0
  end

  def owed_by_joint_account?
    balance_cents > 0
  end

  def balanced?
    balance_cents.zero?
  end

  def refresh!
    unsettled_entries = joint_account.joint_account_ledger_entries
      .unsettled
      .where("initiator_id = ? OR counterparty_id = ?", user_id, user_id)
      .where(currency: currency)

    borrowed = 0
    lent = 0

    unsettled_entries.each do |entry|
      if entry.partner_owes_joint_account? && entry.initiator_id == user_id
        borrowed += entry.amount_cents
      elsif entry.joint_account_owes_partner? && (entry.initiator_id == user_id || entry.counterparty_id == user_id)
        lent += entry.amount_cents
      end
    end

    update!(
      borrowed_from_account_cents: borrowed,
      lent_to_account_cents: lent,
      balance_cents: lent - borrowed,
      last_calculated_at: Time.current
    )
  end

  private

  def set_last_calculated_at
    self.last_calculated_at ||= Time.current
  end
end

