module JointAccounts
  class BorrowProcessor
    attr_reader :joint_account, :initiator_user, :params, :errors

    def initialize(joint_account:, initiator_user:, params:)
      @joint_account = joint_account
      @initiator_user = initiator_user
      @params = params
      @errors = []
    end

    def call
      validate_inputs
      return failure if @errors.any?

      ActiveRecord::Base.transaction do
        create_ledger_entry
        refresh_balances
      end

      success
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
      failure
    rescue StandardError => e
      @errors << "Failed to process borrow transaction: #{e.message}"
      failure
    end

    private

    attr_reader :ledger_entry

    def validate_inputs
      @errors << "Joint account is required" unless joint_account
      @errors << "Initiator user is required" unless initiator_user
      @errors << "Amount is required" if params[:amount_cents].blank?
      @errors << "Direction is required" if params[:direction].blank?
      
      if params[:amount_cents].present? && params[:amount_cents].to_i <= 0
        @errors << "Amount must be positive"
      end

      if joint_account && !joint_account.active?
        @errors << "Joint account is not active"
      end

      if joint_account && initiator_user && !joint_account.member?(initiator_user)
        @errors << "User is not a member of this joint account"
      end

      if joint_account && params[:counterparty_id].present?
        counterparty = User.find_by(id: params[:counterparty_id])
        if counterparty && !joint_account.member?(counterparty)
          @errors << "Counterparty is not a member of this joint account"
        end
      end
    end

    def create_ledger_entry
      @ledger_entry = joint_account.joint_account_ledger_entries.create!(
        initiator: initiator_user,
        counterparty_id: params[:counterparty_id],
        direction: params[:direction],
        amount_cents: params[:amount_cents],
        currency: params[:currency] || joint_account.currency,
        description: params[:description],
        metadata: params[:metadata] || {}
      )
    end

    def refresh_balances
      affected_user_ids = [initiator_user.id]
      affected_user_ids << params[:counterparty_id] if params[:counterparty_id].present?

      affected_user_ids.compact.uniq.each do |user_id|
        balance = joint_account.joint_account_balances.find_or_create_by!(
          user_id: user_id,
          currency: ledger_entry.currency
        ) do |b|
          b.balance_cents = 0
          b.borrowed_from_account_cents = 0
          b.lent_to_account_cents = 0
        end

        balance.refresh!
      end

      send_notifications
    end

    def send_notifications
      joint_account.active_members.each do |membership|
        next if membership.user_id == initiator_user.id

        JointAccountMailer.borrow_transaction_recorded(ledger_entry, membership.user).deliver_later
      end
    end

    def success
      { success: true, ledger_entry: ledger_entry }
    end

    def failure
      { success: false, errors: @errors }
    end
  end
end

