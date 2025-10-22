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

  scope :shared, -> { where(is_private: false) }
  scope :owned_by, ->(user) { where(assignee: user) }
  scope :upcoming, -> { where("due_at IS NULL OR due_at >= ?", Time.current.beginning_of_day) }

  before_save :sync_completion_timestamp

  private

  def sync_completion_timestamp
    if done? && completed_at.nil?
      self.completed_at = Time.current
    elsif !done? && completed_at.present?
      self.completed_at = nil
    end
  end
end
