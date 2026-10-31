require "test_helper"

class SettingsTest < ActionDispatch::IntegrationTest
  test "update_editor saves editor preference" do
    post settings_editor_path, params: { editor_name: "Cursor" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_equal "Cursor", AppSetting.get("editor_application")
  end

  test "update_theme persists valid theme preference and sets cookie" do
    post settings_theme_path, params: { theme: "dark" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_equal "dark", json["theme"]
    assert_equal "dark", AppSetting.theme
    assert_equal "dark", cookies[:theme]
  end

  test "update_theme falls back to system on invalid theme" do
    post settings_theme_path, params: { theme: "neon_rainbow" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["ok"]
    assert_equal "system", json["theme"]
    assert_equal "system", AppSetting.theme
    assert_equal "system", cookies[:theme]
  end

  test "root path renders theme selection buttons and html data attribute" do
    cookies[:theme] = "dark"
    get root_path

    assert_response :success
    assert_select "html[data-theme-preference='dark']"
    assert_select "body[data-controller~='theme']"
    assert_select "button[data-theme-value='system']"
    assert_select "button[data-theme-value='light']"
    assert_select "button[data-theme-value='dark']"
    assert_select "button[data-theme-value='dark'][aria-pressed='true']"
  end

  test "document show page renders settings with theme options" do
    file = Tempfile.new(["test", ".md"])
    file.write("# Heading\nContent")
    file.close

    get open_documents_path(file_path: file.path)
    assert_response :success
    assert_select ".document__actions .home-settings"
    assert_select "button[data-theme-value='dark']"
  ensure
    file&.unlink
  end
end
