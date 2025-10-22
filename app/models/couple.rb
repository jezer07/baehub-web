class Couple < ApplicationRecord
  has_many :users, dependent: :nullify
  has_many :invitations, dependent: :destroy
  has_many :tasks, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :reminders, dependent: :destroy
  has_many :activity_logs, dependent: :destroy

  validates :name, presence: true, length: { minimum: 2, maximum: 80 }
  validates :slug, presence: true, uniqueness: true
  validates :timezone, presence: true

  before_validation :assign_slug, on: :create
  before_validation :normalize_timezone

  def to_param
    slug
  end

  private

  def assign_slug
    return if slug.present?

    loop do
      tentative = SecureRandom.alphanumeric(8).downcase
      next if self.class.exists?(slug: tentative)

      self.slug = tentative
      break
    end
  end

  def normalize_timezone
    self.timezone = timezone.presence || "UTC"
  end
end
