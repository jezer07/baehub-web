module JointAccounts
  class BalanceRefresher
    attr_reader :joint_account, :user, :errors

    def initialize(joint_account:, user: nil)
      @joint_account = joint_account
      @user = user
      @errors = []
    end

    def call
      validate_inputs
      return failure if @errors.any?

      if user
        refresh_user_balance
      else
        refresh_all_balances
      end

      success
    rescue StandardError => e
      @errors << "Failed to refresh balances: #{e.message}"
      failure
    end

    private

    def validate_inputs
      @errors << "Joint account is required" unless joint_account
    end

    def refresh_user_balance
      balances = joint_account.joint_account_balances.where(user: user)
      
      if balances.empty?
        joint_account.joint_account_balances.create!(
          user: user,
          currency: joint_account.currency,
          balance_cents: 0,
          borrowed_from_account_cents: 0,
          lent_to_account_cents: 0
        )
        
        balances = joint_account.joint_account_balances.where(user: user)
      end

      balances.each(&:refresh!)
    end

    def refresh_all_balances
      currencies = joint_account.joint_account_ledger_entries.pluck(:currency).uniq
      members = joint_account.active_members

      members.each do |membership|
        currencies.each do |currency|
          balance = joint_account.joint_account_balances.find_or_create_by!(
            user: membership.user,
            currency: currency
          ) do |b|
            b.balance_cents = 0
            b.borrowed_from_account_cents = 0
            b.lent_to_account_cents = 0
          end

          balance.refresh!
        end
      end
    end

    def success
      { success: true, refreshed_count: user ? 1 : joint_account.active_members.count }
    end

    def failure
      { success: false, errors: @errors }
    end
  end
end

