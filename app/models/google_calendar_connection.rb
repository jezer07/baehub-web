class GoogleCalendarConnection < ApplicationRecord
  belongs_to :couple
  belongs_to :user

  validates :access_token, presence: true

  def calendar_selected?
    calendar_id.present?
  end

  def access_token_expired?
    return true if expires_at.blank?

    Time.current >= (expires_at - 2.minutes)
  end
end
