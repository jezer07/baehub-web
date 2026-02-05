class SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_couple!

  def show
    prepare_form_objects
  end

  def update
    prepare_form_objects

    couple_result = update_couple_preferences
    user_result = update_user_preferences

    if couple_result && user_result
      redirect_to settings_path, notice: "Settings updated successfully."
    else
      flash.now[:alert] = collect_error_messages.presence || "Unable to update settings."
      render :show, status: :unprocessable_entity
    end
  end

  private

  def require_couple!
    unless current_user.couple
      redirect_to new_pairing_path, alert: "Create your shared space before updating settings."
    end
  end

  def prepare_form_objects
    @couple = current_user.couple
    @user = current_user
    @google_connection = @couple.google_calendar_connection

    if @google_connection
      @google_calendars = GoogleCalendar::SyncService.new(@google_connection).available_calendars
    end
  rescue GoogleCalendar::RequestError => e
    @google_calendar_error = e.message
  end

  def update_couple_preferences
    attributes = couple_settings_params
    return true if attributes.empty?

    if @couple.update(attributes)
      true
    else
      false
    end
  end

  def update_user_preferences
    attributes = user_settings_params
    return true if attributes.empty?

    if @user.update(attributes)
      true
    else
      false
    end
  end

  def settings_params
    params.require(:settings).permit(couple: [ :default_currency ], user: [ :prefers_dark_mode ])
  rescue ActionController::ParameterMissing
    ActionController::Parameters.new
  end

  def couple_settings_params
    value = settings_params[:couple]
    return {} unless value.present?

    value.to_h
  end

  def user_settings_params
    value = settings_params[:user]
    return {} unless value.present?

    value.to_h
  end

  def collect_error_messages
    messages = []
    messages.concat(@couple.errors.full_messages) if defined?(@couple) && @couple&.errors&.any?
    messages.concat(@user.errors.full_messages) if defined?(@user) && @user&.errors&.any?
    messages.uniq.to_sentence if messages.any?
  end
end
