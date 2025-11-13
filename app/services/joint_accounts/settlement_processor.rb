module JointAccounts
  class SettlementProcessor
    attr_reader :joint_account, :settled_by_user, :params, :errors

    def initialize(joint_account:, settled_by_user:, params:)
      @joint_account = joint_account
      @settled_by_user = settled_by_user
      @params = params
      @errors = []
    end

    def call
      validate_inputs
      return failure if @errors.any?

      ActiveRecord::Base.transaction do
        create_settlement
        link_ledger_entries
        refresh_balances
      end

      success
    rescue ActiveRecord::RecordInvalid => e
      @errors << e.message
      failure
    rescue StandardError => e
      @errors << "Failed to process settlement: #{e.message}"
      failure
    end

    private

    attr_reader :settlement, :ledger_entries

    def validate_inputs
      @errors << "Joint account is required" unless joint_account
      @errors << "Settled by user is required" unless settled_by_user
      @errors << "Ledger entry IDs are required" if params[:ledger_entry_ids].blank?
      @errors << "Total amount is required" if params[:total_amount_cents].blank?

      if params[:total_amount_cents].present? && params[:total_amount_cents].to_i <= 0
        @errors << "Total amount must be positive"
      end

      if joint_account && !joint_account.active?
        @errors << "Joint account is not active"
      end

      if joint_account && settled_by_user && !joint_account.member?(settled_by_user)
        @errors << "User is not a member of this joint account"
      end

      validate_ledger_entries
    end

    def validate_ledger_entries
      return unless joint_account && params[:ledger_entry_ids].present?

      @ledger_entries = joint_account.joint_account_ledger_entries
        .where(id: params[:ledger_entry_ids])
        .unsettled

      if @ledger_entries.size != params[:ledger_entry_ids].size
        @errors << "Some ledger entries are invalid or already settled"
      end

      total_cents = @ledger_entries.sum(:amount_cents)
      expected_total = params[:total_amount_cents].to_i

      if total_cents != expected_total
        @errors << "Total amount does not match sum of ledger entries (expected: #{total_cents}, got: #{expected_total})"
      end
    end

    def create_settlement
      @settlement = joint_account.joint_account_settlements.create!(
        settled_by: settled_by_user,
        total_amount_cents: params[:total_amount_cents],
        currency: params[:currency] || joint_account.currency,
        settlement_date: params[:settlement_date] || Date.current,
        notes: params[:notes],
        payment_method: params[:payment_method],
        metadata: params[:metadata] || {}
      )
    end

    def link_ledger_entries
      ledger_entries.each do |entry|
        settlement.joint_account_settlement_entries.create!(
          joint_account_ledger_entry: entry
        )
      end
    end

    def refresh_balances
      affected_user_ids = ledger_entries.flat_map do |entry|
        [entry.initiator_id, entry.counterparty_id].compact
      end.uniq

      affected_user_ids.each do |user_id|
        balance = joint_account.joint_account_balances.find_by(
          user_id: user_id,
          currency: settlement.currency
        )

        balance&.refresh!
      end

      send_notifications
    end

    def send_notifications
      joint_account.active_members.each do |membership|
        next if membership.user_id == settled_by_user.id

        JointAccountMailer.settlement_completed(settlement, membership.user).deliver_later
      end
    end

    def success
      { success: true, settlement: settlement }
    end

    def failure
      { success: false, errors: @errors }
    end
  end
end

