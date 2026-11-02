require "test_helper"

class HomeTest < ActionDispatch::IntegrationTest
  test "renders the settings button" do
    get root_path

    assert_response :success
    assert_select ".home-settings__button"
  end

  test "renders the workspace switcher with the current workspace data" do
    user = User.create!(name: "Alpha Workspace")

    get root_path(user_token: user.token)

    assert_response :success
    assert_select ".workspace-switcher__toggle"
    assert_select ".home[data-workspace-modal-token-value='#{user.token}']"
    assert_select ".home[data-workspace-modal-name-value='Alpha Workspace']"
    assert_select "ul.workspace-list[data-workspace-modal-target='savedList']"
  end

  test "renders the file browser button beside the file input without loading file tree initially" do
    original_scan = Filesystem::DirectoryScanner.method(:scan)
    scanned = false
    Filesystem::DirectoryScanner.define_singleton_method(:scan) do |*args|
      scanned = true
      original_scan.call(*args)
    end

    begin
      get root_path
    ensure
      Filesystem::DirectoryScanner.define_singleton_method(:scan, original_scan)
    end

    assert_response :success
    assert_not scanned, "Filesystem::DirectoryScanner.scan should not be called on home page load"
    assert_select ".home__input-group button.home__file-tree-button[aria-label='Browse files']"
    assert_select ".home__input-group button.home__file-tree-button[data-tooltip='Browse files (⌘B)']"
    assert_select "aside.file-sidebar#home_sidebar[hidden]"
    assert_select "turbo-frame#home_sidebar_tree"
    assert_select "turbo-frame#home_sidebar_tree[src]", count: 0
  end
end
