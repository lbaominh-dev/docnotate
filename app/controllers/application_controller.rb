class ApplicationController < ActionController::Base
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :cloud_mode?, :local_mode?, :theme_preference
  before_action :set_current_user

  def theme_preference
    cookies[:theme].presence_in(AppSetting::THEMES) || AppSetting.theme
  end

  def cloud_mode?
    Docnotate.cloud?
  end

  def local_mode?
    Docnotate.local?
  end

  private

  def set_current_user
    token = params[:user_token].presence || cookies.encrypted[:user_token].presence || session[:user_token].presence
    user = User.authenticate_by_token(token)

    if user
      if params[:user_token].present? && cookies.encrypted[:user_token] != user.token
        cookies.encrypted[:user_token] = { value: user.token, expires: 1.year.from_now }
        session[:user_token] = user.token
      end
    else
      user = User.create!(name: "My Workspace")
      cookies.encrypted[:user_token] = { value: user.token, expires: 1.year.from_now }
      session[:user_token] = user.token
    end

    Current.user = user
  end

  def current_user
    Current.user
  end
end
