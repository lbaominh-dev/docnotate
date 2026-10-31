class ApplicationController < ActionController::Base
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user
  before_action :set_current_user

  private

  def set_current_user
    token = params[:user_token].presence || cookies.encrypted[:user_token].presence || session[:user_token].presence
    user = User.authenticate_by_token(token)

    unless user
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
