class ConfigurationsController < ApplicationController
  def ios_v1
    render :ios_v1, formats: :json
  end

  def android_v1
    render :android_v1, formats: :json
  end
end
