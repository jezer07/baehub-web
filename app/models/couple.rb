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

  before_validation :assign_slug, on: :create
  before_validation :normalize_timezone

  def to_param
    slug
  end

  def calculate_balance
    return { balances_by_currency: {}, summary: [] } if users.size < 2

    # Get all expenses and settlements (not just unsettled)
    all_expenses = expenses.includes(:spender, expense_shares: :user)
    all_settlements = settlements.includes(:payer, :payee)

    return { balances_by_currency: {}, summary: [] } if all_expenses.empty? && all_settlements.empty?

    balances_by_currency = {}
    couple_user_ids = users.pluck(:id)

    # Get all currencies from both expenses and settlements
    all_currencies = (all_expenses.pluck(:currency) + all_settlements.pluck(:currency)).uniq

    all_currencies.each do |currency|
      user_balances = {}

      # Initialize balances for each user
      users.each do |user|
        user_balances[user.id] = { paid: 0, owes: 0, settlements_made: 0, settlements_received: 0, net: 0 }
      end

      # Process expenses for this currency
      currency_expenses = all_expenses.select { |e| e.currency == currency }
      currency_expenses.each do |expense|
        # Track what was paid
        user_balances[expense.spender_id][:paid] += expense.amount_cents if couple_user_ids.include?(expense.spender_id)

        # Track what is owed
        expense.expense_shares.each do |share|
          if share.user_id.present? && couple_user_ids.include?(share.user_id)
            user_balances[share.user_id][:owes] += share.calculated_amount
          end
        end
      end

      # Process settlements for this currency
      currency_settlements = all_settlements.select { |s| s.currency == currency }
      currency_settlements.each do |settlement|
        # Track settlements made (reduces what you're owed)
        if couple_user_ids.include?(settlement.payer_id)
          user_balances[settlement.payer_id][:settlements_made] += settlement.amount_cents
        end

        # Track settlements received (reduces what you owe)
        if couple_user_ids.include?(settlement.payee_id)
          user_balances[settlement.payee_id][:settlements_received] += settlement.amount_cents
        end
      end

      # Calculate net balance for each user
      # Formula: (paid - owed) + (settlements_made - settlements_received)
      # Positive = they are owed money
      # Negative = they owe money
      user_balances.each do |user_id, balance|
        expense_balance = balance[:paid] - balance[:owes]
        settlement_balance = balance[:settlements_made] - balance[:settlements_received]
        balance[:net] = expense_balance + settlement_balance
      end

      balances_by_currency[currency] = user_balances
    end

    summary = []
    user_map = users.index_by(&:id)

    balances_by_currency.each do |currency, user_balances|
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
end
