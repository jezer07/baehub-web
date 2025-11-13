module JointAccounts
  class ReconciliationJob < ApplicationJob
    queue_as :default

    def perform
      joint_accounts = JointAccount.active_accounts

      inconsistencies = []

      joint_accounts.each do |joint_account|
        joint_account.joint_account_balances.each do |balance|
          calculated_balance = calculate_balance_from_ledger(joint_account, balance.user, balance.currency)

          if calculated_balance[:balance_cents] != balance.balance_cents
            inconsistencies << {
              joint_account_id: joint_account.id,
              joint_account_name: joint_account.name,
              user_id: balance.user_id,
              user_name: balance.user.name,
              expected_balance: calculated_balance[:balance_cents],
              actual_balance: balance.balance_cents,
              difference: calculated_balance[:balance_cents] - balance.balance_cents
            }

            balance.refresh!
          end
        end
      end

      if inconsistencies.any?
        Rails.logger.warn("Reconciliation found #{inconsistencies.count} inconsistencies: #{inconsistencies.inspect}")
      else
        Rails.logger.info("Reconciliation completed successfully with no inconsistencies")
      end

      inconsistencies
    rescue StandardError => e
      Rails.logger.error("Reconciliation job failed: #{e.message}")
      raise
    end

    private

    def calculate_balance_from_ledger(joint_account, user, currency)
      unsettled_entries = joint_account.joint_account_ledger_entries
        .unsettled
        .where("initiator_id = ? OR counterparty_id = ?", user.id, user.id)
        .where(currency: currency)

      borrowed = 0
      lent = 0

      unsettled_entries.each do |entry|
        if entry.partner_owes_joint_account? && entry.initiator_id == user.id
          borrowed += entry.amount_cents
        elsif entry.joint_account_owes_partner? && (entry.initiator_id == user.id || entry.counterparty_id == user.id)
          lent += entry.amount_cents
        end
      end

      {
        borrowed_from_account_cents: borrowed,
        lent_to_account_cents: lent,
        balance_cents: lent - borrowed
      }
    end
  end
end

