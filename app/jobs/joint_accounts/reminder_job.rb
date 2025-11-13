module JointAccounts
  class ReminderJob < ApplicationJob
    queue_as :default

    def perform
      joint_accounts_with_balances = JointAccount.active_accounts.includes(:joint_account_balances)

      joint_accounts_with_balances.each do |joint_account|
        outstanding_balances = joint_account.joint_account_balances.where.not(balance_cents: 0)

        next if outstanding_balances.empty?

        outstanding_balances.each do |balance|
          next unless balance.user

          if balance.owes_to_joint_account?
            JointAccountMailer.outstanding_balance_reminder(balance).deliver_later
          end
        end
      end

      Rails.logger.info("Reminder job completed for #{joint_accounts_with_balances.count} joint accounts")
    rescue StandardError => e
      Rails.logger.error("Reminder job failed: #{e.message}")
      raise
    end
  end
end

