class SettingsController < ApplicationController
  def update_editor
    editor_name = params[:editor_name].presence
    AppSetting.set("editor_application", editor_name || EditorOpener::DEFAULT)
    render json: { ok: true }
  end

  def update_theme
    theme = params[:theme].to_s.presence_in(AppSetting::THEMES) || AppSetting::DEFAULT_THEME
    AppSetting.theme = theme
    cookies[:theme] = { value: theme, expires: 1.year.from_now, same_site: :lax }
    render json: { ok: true, theme: theme }
  end
end
