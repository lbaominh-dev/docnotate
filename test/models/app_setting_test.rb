require "test_helper"

class AppSettingTest < ActiveSupport::TestCase
  test "get returns the stored value for a key" do
    AppSetting.create!(key: "editor_application", value: "Visual Studio Code")

    assert_equal "Visual Studio Code", AppSetting.get("editor_application")
  end

  test "get returns nil when the key is not set" do
    assert_nil AppSetting.get("missing_key")
  end

  test "set upserts the value for a key" do
    AppSetting.set("editor_application", "Visual Studio Code")
    AppSetting.set("editor_application", "Cursor")

    assert_equal "Cursor", AppSetting.get("editor_application")
    assert_equal 1, AppSetting.count
  end

  test "theme defaults to system when not configured" do
    assert_equal "system", AppSetting.theme
  end

  test "theme sets and retrieves valid theme preference" do
    AppSetting.theme = "dark"
    assert_equal "dark", AppSetting.theme

    AppSetting.theme = "light"
    assert_equal "light", AppSetting.theme

    AppSetting.theme = "invalid_theme"
    assert_equal "system", AppSetting.theme
  end
end
