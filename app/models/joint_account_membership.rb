class JointAccountMembership < ApplicationRecord
  belongs_to :joint_account
  belongs_to :user

  enum :role, {
    member: "member",
    admin: "admin"
  }, default: :member, validate: true

  validates :joined_at, presence: true
  validates :user_id, uniqueness: { scope: :joint_account_id, message: "is already a member of this joint account" }
  validate :user_must_be_in_same_couple

  before_validation :set_joined_at, on: :create

  scope :active_memberships, -> { where(active: true) }
  scope :inactive_memberships, -> { where(active: false) }
  scope :for_joint_account, ->(joint_account_id) { where(joint_account_id: joint_account_id) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  def deactivate!
    update!(active: false, left_at: Time.current)
  end

  def reactivate!
    update!(active: true, left_at: nil)
  end

  private

  def set_joined_at
    self.joined_at ||= Time.current
  end

  def user_must_be_in_same_couple
    return unless joint_account && user

    if joint_account.couple_id != user.couple_id
      errors.add(:user, "must be in the same couple as the joint account")
    end
  end
end

