class ExpenseShare < ApplicationRecord
  belongs_to :expense
  belongs_to :user, optional: true

  validates :expense, uniqueness: { scope: :user_id }, if: -> { user_id.present? }
  validates :percentage, numericality: { greater_than: 0, less_than_or_equal_to: 100 }, if: -> { percentage.present? }
  validates :amount_cents, numericality: { greater_than: 0 }, if: -> { amount_cents.present? }
  
  validate :value_presence
  validate :user_in_same_couple

  def calculated_amount
    return amount_cents if amount_cents.present?
    return (expense.amount_cents * percentage / 100.0).round if percentage.present?
    0
  end

  def formatted_amount
    amount_value = calculated_amount / 100.0
    "#{expense.currency_symbol}#{'%.2f' % amount_value}"
  end

  def share_type
    return :amount if amount_cents.present?
    return :percentage if percentage.present?
    :unknown
  end

  private

  def value_presence
    return if amount_cents.present? || percentage.present?

    errors.add(:base, "amount or percentage must be provided")
  end

  def user_in_same_couple
    return if user.blank? || expense.blank?

    if user.couple_id != expense.couple_id
      errors.add(:user, "must belong to the same couple as the expense")
    end
  end
end
