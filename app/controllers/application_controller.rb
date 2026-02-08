class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[name avatar_url preferred_color timezone])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name avatar_url preferred_color timezone])
  end

  def after_sign_in_path_for(resource)
    dashboard_path
  end

  def after_sign_out_path_for(_resource_or_scope)
    hotwire_native_app? ? new_user_session_path : root_path
  end

  def log_exception(error, context:)
    Rails.logger.error("[#{context}] #{error.class}: #{error.message}")
    Rails.logger.error(error.backtrace.first(10).join("\n")) if error.backtrace.present?
  end

  def generic_error_message
    "Something went wrong. Please try again."
  end
end
