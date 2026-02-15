class HomeController < ApplicationController
  def index
    redirect_to new_user_session_path if hotwire_native_app?
  end

  def privacy_policy
  end
end
