require "securerandom"

class GoogleCalendarConnectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_couple!

  def connect
    if ENV["GOOGLE_CLIENT_ID"].blank? || ENV["GOOGLE_CLIENT_SECRET"].blank?
      redirect_to settings_path, alert: "Google Calendar credentials are not configured."
      return
    end

    state = SecureRandom.hex(16)
    session[:google_oauth_state] = state

    redirect_to GoogleCalendar::Oauth.authorization_url(
      redirect_uri: callback_url,
      state: state
    ), allow_other_host: true
  end

  def callback
    if params[:error].present?
      redirect_to settings_path, alert: params[:error_description] || "Google authorization failed."
      return
    end

    state = session.delete(:google_oauth_state)
    if state.blank? || params[:state] != state
      redirect_to settings_path, alert: "Google authorization could not be verified."
      return
    end

    if params[:code].blank?
      redirect_to settings_path, alert: "Google authorization code missing."
      return
    end

    tokens = GoogleCalendar::Oauth.exchange_code(code: params[:code], redirect_uri: callback_url)
    connection = current_user.couple.google_calendar_connection || current_user.couple.build_google_calendar_connection(user: current_user)

    connection.assign_attributes(
      access_token: tokens[:access_token],
      refresh_token: tokens[:refresh_token].presence || connection.refresh_token,
      expires_at: Time.current + tokens[:expires_in].seconds
    )
    connection.user = current_user
    connection.save!

    redirect_to settings_path, notice: "Google account connected. Choose a shared calendar to sync."
  rescue GoogleCalendar::RequestError => e
    log_exception(e, context: "google_calendar_connections#callback")
    redirect_to settings_path, alert: "Google connection failed. Please try again."
  end

  def select_calendar
    connection = current_user.couple.google_calendar_connection
    unless connection
      redirect_to settings_path, alert: "Connect a Google account first."
      return
    end

    calendar_id = params[:calendar_id]
    if calendar_id.blank?
      redirect_to settings_path, alert: "Select a calendar to continue."
      return
    end

    calendars = GoogleCalendar::SyncService.new(connection).available_calendars
    selected = calendars.find { |item| item[:id] == calendar_id }
    unless selected
      redirect_to settings_path, alert: "Selected calendar is not available."
      return
    end
    calendar_summary = selected[:summary]

    connection.update!(
      calendar_id: calendar_id,
      calendar_summary: calendar_summary || calendar_id
    )
    GoogleCalendar::InitialSyncJob.perform_later(connection.id)
    redirect_to settings_path, notice: "Shared calendar linked. Initial sync is running."
  rescue GoogleCalendar::RequestError => e
    log_exception(e, context: "google_calendar_connections#select_calendar")
    redirect_to settings_path, alert: "Google Calendar sync failed. Please try again."
  end

  def disconnect
    connection = current_user.couple.google_calendar_connection
    if connection
      GoogleCalendar::SyncService.new(connection).stop_watch!
      connection.destroy
      current_user.couple.events.update_all(
        sync_to_google: false,
        google_event_id: nil,
        google_event_etag: nil,
        google_event_updated_at: nil,
        google_last_synced_at: nil,
        google_sync_status: nil,
        google_sync_error: nil
      )
    end

    redirect_to settings_path, notice: "Google Calendar disconnected."
  end

  private

  def ensure_couple!
    return if current_user.couple.present?

    redirect_to new_pairing_path, alert: "Create your shared space before connecting calendars."
  end

  def callback_url
    "#{request.base_url}/auth/google_oauth2/callback"
  end
end
