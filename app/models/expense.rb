class Expense < ApplicationRecord
  belongs_to :couple
  belongs_to :spender, class_name: "User"

  has_many :expense_shares, dependent: :destroy
  has_many :reminders, as: :remindable, dependent: :destroy
  has_many :activity_logs, as: :subject, dependent: :destroy

  enum :split_strategy, { equal: "equal", percentage: "percentage", custom_amounts: "custom_amounts" }, default: :equal, validate: true

  validates :title, presence: true, length: { maximum: 140 }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :incurred_on, presence: true

  before_validation :normalize_currency

  def amount
    amount_cents / 100.0
  end

  private

  def normalize_currency
    self.currency = currency.to_s.upcase.presence || "USD"
  end
end
