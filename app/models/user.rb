class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable, :confirmable

  belongs_to :couple, optional: true

  has_many :sent_invitations, class_name: "Invitation", foreign_key: :sender_id, dependent: :nullify, inverse_of: :sender
  has_many :created_tasks, class_name: "Task", foreign_key: :creator_id, dependent: :nullify, inverse_of: :creator
  has_many :assigned_tasks, class_name: "Task", foreign_key: :assignee_id, dependent: :nullify, inverse_of: :assignee
  has_many :created_events, class_name: "Event", foreign_key: :creator_id, dependent: :nullify, inverse_of: :creator
  has_many :event_responses, dependent: :destroy
  has_many :expenses_paid, class_name: "Expense", foreign_key: :spender_id, dependent: :nullify, inverse_of: :spender
  has_many :settlements_made, class_name: "Settlement", foreign_key: :payer_id, dependent: :nullify, inverse_of: :payer
  has_many :settlements_received, class_name: "Settlement", foreign_key: :payee_id, dependent: :nullify, inverse_of: :payee
  has_many :reminders_sent, class_name: "Reminder", foreign_key: :sender_id, dependent: :nullify, inverse_of: :sender
  has_many :reminders_received, class_name: "Reminder", foreign_key: :recipient_id, dependent: :nullify, inverse_of: :recipient
  has_many :expense_shares, dependent: :destroy
  has_many :activity_logs, dependent: :nullify
  has_many :push_subscriptions, dependent: :destroy

  enum :role, { partner: "partner", solo: "solo" }, default: :partner, validate: true

  validates :name, presence: true, length: { minimum: 2, maximum: 50 }
  validates :timezone, allow_nil: true, length: { maximum: 100 }
  validates :preferred_color, allow_nil: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a hex color" }

  def paired?
    couple_id.present? && !solo_mode?
  end
end
