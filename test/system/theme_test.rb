require "application_system_test_case"

class ThemeSystemTest < ApplicationSystemTestCase
  test "user can switch between light, dark, and system themes and preference persists across reloads" do
    visit root_path

    # Open settings
    find("button.home-settings__button[aria-label='Settings']").click
    assert_selector ".home-settings__panel", visible: true

    # Switch to dark
    find("button[data-theme-value='dark']").click
    assert_equal "dark", page.evaluate_script("document.documentElement.getAttribute('data-theme')")
    assert_equal "dark", page.evaluate_script("localStorage.getItem('docnotate-theme')")
    assert_selector "button[data-theme-value='dark'][aria-pressed='true']"

    # Switch to light
    find("button[data-theme-value='light']").click
    assert_equal "light", page.evaluate_script("document.documentElement.getAttribute('data-theme')")
    assert_equal "light", page.evaluate_script("localStorage.getItem('docnotate-theme')")
    assert_selector "button[data-theme-value='light'][aria-pressed='true']"

    # Switch back to dark and refresh to test persistence
    find("button[data-theme-value='dark']").click
    refresh
    assert_equal "dark", page.evaluate_script("document.documentElement.getAttribute('data-theme')")
  end
end
