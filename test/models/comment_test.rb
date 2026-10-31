require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "document_version_id must belong to the same document" do
    document = Document.create!(
      file_path: "/tmp/doc.md",
      content: "# Hello",
      file_type: "markdown"
    )
    document.parse_ast_and_save!(metadata: Documents::AstParseable::ParseMetadata.new(size: 100, last_modified_at: Time.current))

    other_document = Document.create!(
      file_path: "/tmp/other.md",
      content: "# Other",
      file_type: "markdown"
    )
    other_document.parse_ast_and_save!(metadata: Documents::AstParseable::ParseMetadata.new(size: 100, last_modified_at: Time.current))

    comment = document.comments.new(content: "Comment")
    comment.document_version = other_document.current_version

    assert_not comment.valid?
    assert_includes comment.errors[:document_version_id], "must belong to the same document"
  end

  test "auto-assigns current document version on create" do
    document = Document.create!(
      file_path: "/tmp/doc.md",
      content: "# Hello",
      file_type: "markdown"
    )
    document.parse_ast_and_save!(metadata: Documents::AstParseable::ParseMetadata.new(size: 100, last_modified_at: Time.current))

    comment = document.comments.create!(content: "Comment")

    assert_equal document.current_version, comment.document_version
  end

  test "rendered_content renders markdown" do
    document = Document.create!(
      file_path: "/tmp/doc.md",
      content: "# Hello",
      file_type: "markdown"
    )
    document.parse_ast_and_save!(metadata: Documents::AstParseable::ParseMetadata.new(size: 100, last_modified_at: Time.current))

    comment = document.comments.build(content: "Fix `-v` flag first:\n\n- one\n- two")

    html = comment.rendered_content

    assert_match %r{<p>Fix <code>-v</code> flag first:</p>}, html
    assert_match %r{<li>one</li>}, html
  end

  test "rendered_content neutralizes raw html from agent content" do
    document = Document.create!(
      file_path: "/tmp/doc.md",
      content: "# Hello",
      file_type: "markdown"
    )
    document.parse_ast_and_save!(metadata: Documents::AstParseable::ParseMetadata.new(size: 100, last_modified_at: Time.current))

    comment = document.comments.build(content: "<script>alert(1)</script><img src=x onerror=alert(1)>")

    html = comment.rendered_content
    assert_not_includes html, "<script>"
    assert_not_includes html, "<img"
  end

  test "create_comment! successfully anchors multi-line selected_text in wrapped paragraph" do
    content = <<~MARKDOWN
      This is a paragraph with a very long sentence
      that wraps to the next line in the source markdown
      and finishes here.
    MARKDOWN

    document = Document.open("sample_wrap.md", content: content)
    selected_text = "This is a paragraph with a very long sentence\nthat wraps to the next line"

    comment = document.create_comment!(
      content: "Review line wrap",
      selected_text: selected_text
    )

    assert comment.persisted?
    assert comment.start_block_id.present?
    assert_equal comment.start_block_id, comment.end_block_id
    assert_equal 0, comment.start_offset
    assert_equal 72, comment.end_offset
  end

  test "create_comment! successfully anchors multi-block selected_text across heading and paragraph" do
    content = <<~MARKDOWN
      ## Important Goal
      Verify that DocNotate Cloud deployment works seamlessly with remote MCP server.
    MARKDOWN

    document = Document.open("sample_multiblock.md", content: content)
    selected_text = "## Important Goal\nVerify that DocNotate Cloud deployment"

    comment = document.create_comment!(
      content: "Check heading and paragraph",
      selected_text: selected_text
    )

    assert comment.persisted?
    assert comment.start_block_id.present?
    assert comment.end_block_id.present?
    assert_not_equal comment.start_block_id, comment.end_block_id
    assert_equal 0, comment.start_offset
  end

  test "create_comment! successfully anchors multi-block selected_text across list items with bullets" do
    content = <<~MARKDOWN
      - First item in the list
      - Second item in the list
      - Third item in the list
    MARKDOWN

    document = Document.open("sample_list.md", content: content)
    selected_text = "- First item in the list\n- Second item in the list"

    comment = document.create_comment!(
      content: "Check list items",
      selected_text: selected_text
    )

    assert comment.persisted?
    assert comment.start_block_id.present?
    assert comment.end_block_id.present?
    assert_not_equal comment.start_block_id, comment.end_block_id
  end
end
