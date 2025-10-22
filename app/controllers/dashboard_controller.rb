class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!

  def show
    @couple = current_user.couple
    @tasks = @couple.tasks.shared.order(:status, :due_at).limit(6)
    @events = @couple.events.future.order(:starts_at).limit(4)
    @expenses = @couple.expenses.order(incurred_on: :desc).limit(4)
    @activity_logs = @couple.activity_logs.recent
    @active_invitations = @couple.invitations.active
  end

  private

  def ensure_couple!
    return if current_user.couple.present?

    redirect_to new_pairing_path, notice: "Let’s link you with your person before exploring the dashboard."
  end
end
