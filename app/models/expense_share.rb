class ExpenseShare < ApplicationRecord
  belongs_to :expense
  belongs_to :user, optional: true

  validates :expense, uniqueness: { scope: :user_id }, if: -> { user_id.present? }
  validate :value_presence

  private

  def value_presence
    return if amount_cents.present? || percentage.present?

    errors.add(:base, "amount or percentage must be provided")
  end
end
