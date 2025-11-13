class JointAccountMailer < ApplicationMailer
  default from: "notifications@baehub.com"

  def joint_account_created(joint_account, user)
    @joint_account = joint_account
    @user = user
    @created_by = joint_account.created_by

    mail(
      to: @user.email,
      subject: "You've been added to #{@joint_account.name}"
    )
  end

  def borrow_transaction_recorded(ledger_entry, recipient_user)
    @ledger_entry = ledger_entry
    @joint_account = ledger_entry.joint_account
    @recipient = recipient_user
    @initiator = ledger_entry.initiator

    mail(
      to: @recipient.email,
      subject: "New transaction on #{@joint_account.name}"
    )
  end

  def settlement_completed(settlement, recipient_user)
    @settlement = settlement
    @joint_account = settlement.joint_account
    @recipient = recipient_user
    @settled_by = settlement.settled_by

    mail(
      to: @recipient.email,
      subject: "Settlement completed on #{@joint_account.name}"
    )
  end

  def outstanding_balance_reminder(balance)
    @balance = balance
    @joint_account = balance.joint_account
    @user = balance.user

    mail(
      to: @user.email,
      subject: "Outstanding balance reminder for #{@joint_account.name}"
    )
  end

  def weekly_digest(user, joint_accounts_summary)
    @user = user
    @joint_accounts_summary = joint_accounts_summary

    mail(
      to: @user.email,
      subject: "Your weekly joint accounts summary"
    )
  end
end

