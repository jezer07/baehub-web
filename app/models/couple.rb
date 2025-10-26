class Couple < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :invitations, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :activity_logs, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 80 }
  validates :slug, presence: true, uniqueness: true
  validates :timezone, presence: true
  validates :default_currency, presence: true, length: { is: 3 }

  before_validation :assign_slug, on: :create
  before_validation :normalize_timezone
  before_validation :normalize_default_currency

  def to_param
    slug
  end

  def calculate_balance
    return { balances_by_currency: {}, summary: [] } if users.size < 2

    unsettled_expenses_data = expenses.unsettled.includes(:spender, expense_shares: :user)
    
    return { balances_by_currency: {}, summary: [] } if unsettled_expenses_data.empty?

    balances_by_currency = {}
    couple_user_ids = users.pluck(:id)
    
    unsettled_expenses_data.group_by(&:currency).each do |currency, currency_expenses|
      user_balances = {}
      
      users.each do |user|
        user_balances[user.id] = { paid: 0, owes: 0, net: 0 }
      end
      
      currency_expenses.each do |expense|
        user_balances[expense.spender_id][:paid] += expense.amount_cents if couple_user_ids.include?(expense.spender_id)
        
        expense.expense_shares.each do |share|
          if share.user_id.present? && couple_user_ids.include?(share.user_id)
            user_balances[share.user_id][:owes] += share.calculated_amount
          end
        end
      end
      
      user_balances.each do |user_id, balance|
        balance[:net] = balance[:paid] - balance[:owes]
      end
      
      balances_by_currency[currency] = user_balances
    end
    
    summary = []
    
    balances_by_currency.each do |currency, user_balances|
      filtered_user_balances = user_balances.select { |user_id, _balance| couple_user_ids.include?(user_id) }
      
      positive_balance_user_id = filtered_user_balances.find { |_id, balance| balance[:net] > 0 }&.first
      negative_balance_user_id = filtered_user_balances.find { |_id, balance| balance[:net] < 0 }&.first
      
      if positive_balance_user_id && negative_balance_user_id
        creditor = users.find { |u| u.id == positive_balance_user_id }
        debtor = users.find { |u| u.id == negative_balance_user_id }
        
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
    self.default_currency = default_currency.to_s.upcase.presence || "USD"
  end
end
