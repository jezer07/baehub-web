class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :avatar_url])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :avatar_url])
  end

  def after_sign_in_path_for(resource)
    edit_user_registration_path
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end
end
