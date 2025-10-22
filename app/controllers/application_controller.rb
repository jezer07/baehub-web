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

  def after_sign_out_path_for(resource_or_scope)
    root_path
  end
end
