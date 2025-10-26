class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_couple

  def edit
    @couple = current_user.couple
  end

  def update
    @couple = current_user.couple

    if @couple.update(couple_params)
      log_activity(@couple, "Settings updated: #{params_to_log}")
      redirect_to edit_settings_path, notice: "Settings updated successfully."
    else
      flash.now[:alert] = @couple.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def couple_params
    params.require(:couple).permit(:default_currency, :name, :anniversary_on, :timezone, :story)
  end

  def require_couple
    redirect_to new_pairing_path, alert: "You need to be in a couple to access settings." unless current_user.couple
  end

  def params_to_log
    changed_attrs = @couple.previous_changes.keys.reject { |k| k.in?(%w[updated_at]) }
    changed_attrs.map { |attr| attr.humanize }.join(", ")
  end

  def log_activity(couple, action)
    ActivityLog.create!(
      couple:,
      user: current_user,
      action:,
      metadata: { origin: "settings" }
    )
  end
end
