class Task < ApplicationRecord
  belongs_to :couple
  belongs_to :creator, class_name: "User"
  belongs_to :assignee, class_name: "User", optional: true

  has_many :reminders, as: :remindable, dependent: :destroy
  has_many :activity_logs, as: :subject, dependent: :destroy

  enum :status, { todo: 0, in_progress: 1, done: 2, archived: 3 }, default: :todo, validate: true
  enum :priority, { low: 0, normal: 1, high: 2, urgent: 3 }, default: :normal, validate: true

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :assignee, presence: false
  validate :assignee_in_same_couple
  validate :cannot_transition_from_archived

  scope :assigned_to, ->(user_id) { where(assignee_id: user_id) }
  scope :upcoming, -> { where("due_at IS NULL OR due_at >= ?", Time.current.beginning_of_day) }
  scope :by_status, ->(status) { where(status: status) if status.present? }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_due_date, -> { order(Arel.sql("CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at ASC")) }

  before_save :sync_completion_timestamp

  def overdue?
    return false if done? || archived?
    due_at.present? && due_at < Time.current
  end

  def can_transition_to?(new_status)
    # Archived tasks cannot transition back to other statuses
    return false if archived? && new_status != "archived"
    true
  end

  private

  def sync_completion_timestamp
    if done? && completed_at.nil?
      self.completed_at = Time.current
    elsif !done? && completed_at.present?
      self.completed_at = nil
    end
  end

  def assignee_in_same_couple
    return if assignee.blank?

    if assignee.couple_id != couple_id
      errors.add(:assignee, "must belong to the same couple as the task")
    end
  end

  def cannot_transition_from_archived
    return unless status_changed?

    if status_was == "archived" && status != "archived"
      errors.add(:status, "cannot transition from archived to another status")
    end
  end
end
