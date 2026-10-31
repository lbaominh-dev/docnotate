require "test_helper"

class MultiUserAndMcpTest < ActionDispatch::IntegrationTest
  setup do
    @user_a = User.create!(name: "User Alpha")
    @user_b = User.create!(name: "User Beta")

    @doc_a = Document.open("plan-a.md", content: "# Plan Alpha\n\nContent for user A", user: @user_a)
    @doc_b = Document.open("plan-b.md", content: "# Plan Beta\n\nContent for user B", user: @user_b)
  end

  test "client-side file upload creates document for current user" do
    # When user uploads file content from client
    post documents_path, params: {
      user_token: @user_a.token,
      file_name: "uploaded_local.md",
      content: "# Local Content from Client\n\nUploaded via browser"
    }

    assert_redirected_to open_documents_path(file_path: "uploaded_local.md")

    uploaded_doc = Document.find_by(file_path: "uploaded_local.md", user_id: @user_a.id)
    assert uploaded_doc.present?
    assert_equal "uploaded_local.md", uploaded_doc.file_path
    assert_includes uploaded_doc.content, "Local Content from Client"
  end

  test "web UI isolates documents between different users" do
    # User A accesses documents
    get documents_path, params: { user_token: @user_a.token }
    assert_response :success
    assert_select ".documents__name", text: @doc_a.display_name
    assert_select ".documents__name", text: @doc_b.display_name, count: 0

    # User B accesses documents
    get documents_path, params: { user_token: @user_b.token }
    assert_response :success
    assert_select ".documents__name", text: @doc_b.display_name
    assert_select ".documents__name", text: @doc_a.display_name, count: 0
  end

  test "switching workspace token via WorkspacesController" do
    patch workspace_path, params: { user_token: @user_a.token, switch_token: @user_b.token }
    assert_redirected_to root_path
    follow_redirect!
    assert_select ".workspace-bar__name", text: "User Beta"
  end

  test "mcp endpoint rejects requests with missing or invalid token" do
    post mcp_path, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_includes json["error"], "Missing or invalid token"

    post "#{mcp_path}?token=invalid_token", headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :unauthorized
  end

  test "mcp endpoint accepts valid token and scopes tools to user" do
    # Call list_documents tool for User A
    body = {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "list_documents",
        arguments: {}
      }
    }.to_json

    post "#{mcp_path}?token=#{@user_a.token}",
         params: body,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream"
         }

    assert_response :success
    json = JSON.parse(response.body)
    assert json["result"].present?
    tool_text = json.dig("result", "content", 0, "text")
    result_data = JSON.parse(tool_text)
    doc_names = result_data["documents"].map { |d| d["name"] }

    assert_includes doc_names, "plan-a.md"
    assert_not_includes doc_names, "plan-b.md"
  end

  test "mcp user cannot access another user's document by id" do
    # User B tries to read User A's document content
    body = {
      jsonrpc: "2.0",
      id: 2,
      method: "tools/call",
      params: {
        name: "get_document_content",
        arguments: { document_id: @doc_a.id }
      }
    }.to_json

    post "#{mcp_path}?token=#{@user_b.token}",
         params: body,
         headers: {
           "CONTENT_TYPE" => "application/json",
           "ACCEPT" => "application/json, text/event-stream"
         }

    assert_response :success
    json = JSON.parse(response.body)
    tool_text = json.dig("result", "content", 0, "text")
    assert_includes tool_text, "Document not found: id #{@doc_a.id}"
  end
end
