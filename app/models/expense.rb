class Expense < ApplicationRecord
  include CurrencySymbol

  belongs_to :couple
  belongs_to :spender, class_name: "User"

  has_many :expense_shares, dependent: :destroy
  has_many :reminders, as: :remindable, dependent: :destroy
  has_many :activity_logs, as: :subject, dependent: :destroy

  enum :split_strategy, { equal: "equal", percentage: "percentage", custom_amounts: "custom_amounts" }, default: :equal, validate: true

  validates :title, presence: true, length: { maximum: 140 }
  validates :amount_cents, numericality: { greater_than: 0 }
  validates :incurred_on, presence: true

  validate :spender_belongs_to_couple

  scope :by_spender, ->(spender_id) { where(spender_id: spender_id) if spender_id.present? }
  scope :between_dates, ->(start_date, end_date) { where(incurred_on: start_date..end_date) if start_date.present? && end_date.present? }
  scope :recent, -> { order(incurred_on: :desc, created_at: :desc) }

  def amount
    amount_cents / 100.0
  end

  def formatted_amount
    "#{currency_symbol}#{'%.2f' % amount}"
  end

  def total_shares_amount
    expense_shares.sum(:amount_cents)
  end

  def total_shares_percentage
    expense_shares.sum(:percentage)
  end

  def split_summary
    case split_strategy
    when "equal"
      "Split equally"
    when "percentage"
      "Split by percentage"
    when "custom_amounts"
      "Custom split"
    end
  end

  private

  def spender_belongs_to_couple
    return if spender.blank? || couple.blank?

    if spender.couple_id != couple_id
      errors.add(:spender, "must belong to the same couple")
    end
  end
end
