class Settlement < ApplicationRecord
  include CurrencySymbol

  belongs_to :couple
  belongs_to :payer, class_name: "User"
  belongs_to :payee, class_name: "User"

  validates :amount_cents, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 10_000_000, message: "must be less than or equal to 100,000" }
  validates :settled_on, presence: true
  validate :payer_and_payee_must_be_different
  validate :payer_must_belong_to_couple
  validate :payee_must_belong_to_couple

  scope :recent, -> { order(settled_on: :desc, created_at: :desc) }
  scope :for_couple, ->(couple_id) { where(couple_id: couple_id) }

  def amount
    amount_dollars
  end

  def amount_dollars
    amount_cents.present? ? amount_cents / 100.0 : nil
  end

  def amount_dollars=(value)
    if value.present?
      begin
        self.amount_cents = (BigDecimal(value.to_s) * 100).round.to_i
      rescue ArgumentError, TypeError
        self.amount_cents = nil
        errors.add(:amount_dollars, "is invalid")
      end
    else
      self.amount_cents = nil
    end
  end

  def formatted_amount
    "#{currency_symbol}#{'%.2f' % amount}"
  end

  def description
    "#{payer.name} paid #{payee.name} #{formatted_amount}"
  end

  private

  def payer_and_payee_must_be_different
    if payer_id.present? && payer_id == payee_id
      errors.add(:payee_id, "must be different from payer")
    end
  end

  def payer_must_belong_to_couple
    if payer.present? && payer.couple_id != couple_id
      errors.add(:payer, "must belong to the couple")
    end
  end

  def payee_must_belong_to_couple
    if payee.present? && payee.couple_id != couple_id
      errors.add(:payee, "must belong to the couple")
    end
  end

end
