class HomeController < ApplicationController
  def index
    scope = current_user ? Document.where(user_id: [nil, current_user.id]) : Document.all
    @recent_documents = scope.recently_opened.limit(5)
    @editor_preference = AppSetting.get("editor_application")
  end
end
