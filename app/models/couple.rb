class Couple < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :invitations, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :settlements, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :activity_logs, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 80 }
  validates :slug, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :default_currency, presence: true, length: { is: 3 }, inclusion: { in: CurrencyCatalog.codes }

  before_validation :assign_slug, on: :create
  before_validation :normalize_timezone
  before_validation :normalize_default_currency

  def to_param
    slug
  end

  def default_currency_symbol
    CurrencyCatalog.symbol_for(default_currency)
  end

  def calculate_balance
    return { balances_by_currency: {}, summary: [] } if users.size < 2

    all_expenses = expenses.includes(:spender, expense_shares: :user).to_a
    all_settlements = settlements.includes(:payer, :payee).to_a

    return { balances_by_currency: {}, summary: [] } if all_expenses.empty? && all_settlements.empty?

    couple_currency = default_currency
    couple_user_ids = users.pluck(:id)
    balances_by_currency = {}

    expenses_by_currency = all_expenses.group_by { |expense| couple_currency }
    settlements_by_currency = all_settlements.group_by { |settlement| couple_currency }
    all_currencies = (expenses_by_currency.keys + settlements_by_currency.keys).uniq

    all_currencies.each do |currency|
      user_balances = users.to_a.each_with_object({}) do |user, hash|
        hash[user.id] = { paid: 0, owes: 0, settlements_made: 0, settlements_received: 0, net: 0 }
      end

      (expenses_by_currency[currency] || []).each do |expense|
        if couple_user_ids.include?(expense.spender_id) && user_balances[expense.spender_id]
          user_balances[expense.spender_id][:paid] += expense.amount_cents
        end

        expense.expense_shares.each do |share|
          if share.user_id.present? && couple_user_ids.include?(share.user_id) && user_balances[share.user_id]
            user_balances[share.user_id][:owes] += share.calculated_amount
          end
        end
      end

      (settlements_by_currency[currency] || []).each do |settlement|
        if couple_user_ids.include?(settlement.payer_id) && user_balances[settlement.payer_id]
          user_balances[settlement.payer_id][:settlements_made] += settlement.amount_cents
        end
        if couple_user_ids.include?(settlement.payee_id) && user_balances[settlement.payee_id]
          user_balances[settlement.payee_id][:settlements_received] += settlement.amount_cents
        end
      end

      user_balances.each_value do |balance|
        expense_balance = balance[:paid] - balance[:owes]
        balance[:net] = expense_balance + balance[:settlements_made] - balance[:settlements_received]
      end

      balances_by_currency[currency] = user_balances
    end

    summary = []
    user_map = users.index_by(&:id)

    all_currencies.each do |currency|
      user_balances = balances_by_currency[currency]
      next unless user_balances

      filtered_user_balances = user_balances.select { |user_id, _balance| couple_user_ids.include?(user_id) }

      positive_balance_user_id = filtered_user_balances.find { |_id, balance| balance[:net] > 0 }&.first
      negative_balance_user_id = filtered_user_balances.find { |_id, balance| balance[:net] < 0 }&.first

      if positive_balance_user_id && negative_balance_user_id
        creditor = user_map[positive_balance_user_id]
        debtor = user_map[negative_balance_user_id]

        pos_net = user_balances[positive_balance_user_id][:net].abs
        neg_net = user_balances[negative_balance_user_id][:net].abs
        amount_cents = [pos_net, neg_net].min

        summary << {
          currency: currency,
          debtor: debtor,
          creditor: creditor,
          amount_cents: amount_cents
        }
      end
    end

    {
      balances_by_currency: balances_by_currency,
      summary: summary
    }
  end

  private

  def assign_slug
    return if slug.present?

    loop do
      tentative = SecureRandom.alphanumeric(8).downcase
      next if self.class.exists?(slug: tentative)

      self.slug = tentative
      break
    end
  end

  def normalize_timezone
    self.timezone = timezone.presence || "UTC"
  end

  def normalize_default_currency
    normalized = default_currency.to_s.upcase
    normalized = CurrencyCatalog.default_code if normalized.blank?

    unless CurrencyCatalog.codes.include?(normalized)
      normalized = CurrencyCatalog.default_code
    end

    self.default_currency = normalized
  end
end
