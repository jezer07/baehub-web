module JointAccounts
  class BalanceRefreshJob < ApplicationJob
    queue_as :default

    def perform(joint_account_id, user_id = nil)
      joint_account = JointAccount.find_by(id: joint_account_id)
      return unless joint_account

      user = user_id ? User.find_by(id: user_id) : nil

      result = JointAccounts::BalanceRefresher.new(
        joint_account: joint_account,
        user: user
      ).call

      Rails.logger.info("Balance refresh completed for joint account #{joint_account_id}: #{result[:success] ? 'success' : result[:errors].join(', ')}")
    rescue StandardError => e
      Rails.logger.error("Balance refresh failed for joint account #{joint_account_id}: #{e.message}")
      raise
    end
  end
end

