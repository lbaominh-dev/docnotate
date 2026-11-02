require "application_system_test_case"

class WorkspaceSwitcherSystemTest < ApplicationSystemTestCase
  setup do
    @workspace_a = User.create!(name: "Alpha Workspace")
    @workspace_b = User.create!(name: "Beta Workspace")
  end

  test "remembers workspaces in the browser and switches between them" do
    visit root_path(user_token: @workspace_a.token)

    assert_selector ".workspace-bar__name", text: "Alpha Workspace"
    assert_equal [ @workspace_a.token ], stored_workspaces.map { |workspace| workspace["token"] }

    find("button", text: "MCP & Workspace").click
    within(".workspace-modal") do
      fill_in "switch_token", with: @workspace_b.token
      click_button "Add & Switch"
    end

    assert_selector ".workspace-bar__name", text: "Beta Workspace"
    assert_equal [ @workspace_b.token, @workspace_a.token ], stored_workspaces.map { |workspace| workspace["token"] }

    find(".workspace-switcher__toggle").click
    find(".workspace-switcher__item", text: "Alpha Workspace").click

    assert_selector ".workspace-bar__name", text: "Alpha Workspace"
    assert_equal [ @workspace_a.token, @workspace_b.token ], stored_workspaces.map { |workspace| workspace["token"] }
  end

  private

  def stored_workspaces
    JSON.parse(page.evaluate_script("localStorage.getItem('docnotate_workspaces') || '[]'"))
  end
end
