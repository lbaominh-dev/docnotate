# frozen_string_literal: true

require "test_helper"

class ReadDocumentToolTest < ActiveSupport::TestCase
  test "tool definition and annotations" do
    assert_equal "read_document", ReadDocumentTool.tool_name
    assert_equal "Read Document", ReadDocumentTool.title

    annotations = ReadDocumentTool.annotations
    assert_equal false, annotations.read_only_hint
    assert_equal false, annotations.destructive_hint
    assert_equal false, annotations.idempotent_hint
    assert_equal false, annotations.open_world_hint
  end

  test "call with valid markdown file returns metadata and content outline" do
    file = Tempfile.new([ "read_test", ".md" ])
    file.write("# Title\n\nSome body text.")
    file.close

    response = ReadDocumentTool.call(file_path: file.path, server_context: {})
    assert_not response.error?

    data = JSON.parse(response.content.first[:text])
    assert data["id"].present?
    assert_equal File.realpath(file.path), data["file_path"]
    assert_equal "markdown", data["file_type"]
    assert_equal "v1", data["version"]
    assert data["last_opened_at"].present?
    assert data["content_outline"].is_a?(Array)
    assert_not_empty data["content_outline"]
  ensure
    file.unlink
  end

  test "call with non-existent file returns error response" do
    response = ReadDocumentTool.call(file_path: "/non/existent/file.md", server_context: {})
    assert response.error?
    assert_includes response.content.first[:text], "File not found: /non/existent/file.md"
  end
end
