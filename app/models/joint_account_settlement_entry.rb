class JointAccountSettlementEntry < ApplicationRecord
  belongs_to :joint_account_settlement
  belongs_to :joint_account_ledger_entry

  validates :joint_account_ledger_entry_id, uniqueness: { 
    scope: :joint_account_settlement_id, 
    message: "is already included in this settlement" 
  }
  validate :ledger_entry_must_be_unsettled

  after_create :mark_ledger_entry_as_settled

  private

  def ledger_entry_must_be_unsettled
    return unless joint_account_ledger_entry

    if joint_account_ledger_entry.settled?
      errors.add(:joint_account_ledger_entry, "has already been settled")
    end
  end

  def mark_ledger_entry_as_settled
    joint_account_ledger_entry.mark_as_settled!(joint_account_settlement.id.to_s)
  end
end

