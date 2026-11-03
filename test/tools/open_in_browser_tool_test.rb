# frozen_string_literal: true

require "test_helper"

class OpenInBrowserToolTest < ActiveSupport::TestCase
  setup do
    @orig_browser_gate = ENV["DOCNOTATE_OPEN_BROWSER"]
    @orig_base_url = ENV["DOCNOTATE_BASE_URL"]
    @orig_root_url = ENV["DOCNOTATE_ROOT_URL"]
    @orig_port = ENV["PORT"]
    ENV.delete("DOCNOTATE_OPEN_BROWSER")
    ENV.delete("DOCNOTATE_BASE_URL")
    ENV.delete("DOCNOTATE_ROOT_URL")
    ENV.delete("PORT")
    AppSetting.find_by(key: "base_url")&.destroy
  end

  teardown do
    ENV["DOCNOTATE_OPEN_BROWSER"] = @orig_browser_gate if @orig_browser_gate
    ENV["DOCNOTATE_BASE_URL"] = @orig_base_url if @orig_base_url
    ENV["DOCNOTATE_ROOT_URL"] = @orig_root_url if @orig_root_url
    ENV["PORT"] = @orig_port if @orig_port
    AppSetting.find_by(key: "base_url")&.destroy
  end

  test "tool definition and annotations" do
    assert_equal "open_in_browser", OpenInBrowserTool.tool_name
    assert_equal "Open in Browser", OpenInBrowserTool.title

    annotations = OpenInBrowserTool.annotations
    assert_equal false, annotations.read_only_hint
    assert_equal false, annotations.destructive_hint
    assert_equal false, annotations.idempotent_hint
    assert_equal true, annotations.open_world_hint
  end

  test "returns error when both file_path and document_id are provided" do
    response = OpenInBrowserTool.call(file_path: "/path/doc.md", document_id: 1, server_context: {})
    assert response.error?
    assert_equal "Provide either file_path or document_id, not both.", response.content.first[:text]
  end

  test "returns error when neither file_path nor document_id is provided" do
    response = OpenInBrowserTool.call(server_context: {})
    assert response.error?
    assert_equal "Either file_path or document_id is required.", response.content.first[:text]
  end

  test "returns error when document_id is not found" do
    response = OpenInBrowserTool.call(document_id: 999_999, server_context: {})
    assert response.error?
    assert_equal "Document with id 999999 not found.", response.content.first[:text]
  end

  test "returns error for unsupported file type" do
    file = Tempfile.new([ "notes", ".txt" ])
    file.write("Just some text")
    file.close

    response = OpenInBrowserTool.call(file_path: file.path, server_context: {})
    assert response.error?
    assert_includes response.content.first[:text], "Unsupported file type for browser view"
  ensure
    file.unlink
  end

  test "opens by file_path with launch: false returns URL without calling opener" do
    dir = Dir.mktmpdir("doc test")
    file_path = File.join(dir, "my plan.md")
    File.write(file_path, "# A Plan")

    response = OpenInBrowserTool.call(file_path: file_path, launch: false, server_context: {})
    assert_not response.error?

    data = JSON.parse(response.content.first[:text])
    assert_equal false, data["launched"]
    assert_includes data["url"], "http://localhost:3000/documents/open?file_path="
    assert_includes data["url"], "my%20plan.md"
    assert_equal "Browser launch skipped. Open the URL manually.", data["message"]
  ensure
    FileUtils.remove_entry(dir) if dir && File.exist?(dir)
  end

  test "opens by document_id with successful browser launch" do
    file = Tempfile.new([ "existing", ".md" ])
    file.write("# Existing Doc")
    file.close

    doc = Document.open(file.path)

    fake_opener = Class.new do
      def self.open(_url); true; end
    end

    BrowserOpener.stub_bind = fake_opener if defined?(BrowserOpener.stub_bind)

    # Use a custom singleton method or temporary alias
    orig_open = BrowserOpener.method(:open)
    BrowserOpener.define_singleton_method(:open) { |_url| true }

    begin
      response = OpenInBrowserTool.call(document_id: doc.id, server_context: {})
      assert_not response.error?

      data = JSON.parse(response.content.first[:text])
      assert_equal true, data["launched"]
      assert_equal doc.id, data["document_id"]
      assert_includes data["message"], "Opened in browser at"
      assert_equal doc.browser_url, data["url"]
    ensure
      BrowserOpener.define_singleton_method(:open, orig_open)
      file.unlink
    end
  end

  test "failed browser launch reports launched: false with error and returns URL" do
    file = Tempfile.new([ "failed_launch", ".md" ])
    file.write("# Plan")
    file.close

    orig_open = BrowserOpener.method(:open)
    BrowserOpener.define_singleton_method(:open) { |_url| false }

    begin
      response = OpenInBrowserTool.call(file_path: file.path, server_context: {})
      assert_not response.error? # tool succeeded, payload reports launch failure

      data = JSON.parse(response.content.first[:text])
      assert_equal false, data["launched"]
      assert data["url"].present?
      assert data["warning"].present?
      assert_includes data["warning"], "Could not launch desktop browser"
      assert_includes data["message"], "Could not launch desktop browser"
    ensure
      BrowserOpener.define_singleton_method(:open, orig_open)
      file.unlink
    end
  end

  test "honours DOCNOTATE_OPEN_BROWSER=false and '0' env gate" do
    file = Tempfile.new([ "gate_test", ".md" ])
    file.write("# Gate Test")
    file.close

    orig_open = BrowserOpener.method(:open)
    called = false
    BrowserOpener.define_singleton_method(:open) { |_url| called = true; true }

    begin
      ENV["DOCNOTATE_OPEN_BROWSER"] = "false"
      response = OpenInBrowserTool.call(file_path: file.path, server_context: {})
      data = JSON.parse(response.content.first[:text])
      assert_equal false, data["launched"]
      assert_equal false, called

      ENV["DOCNOTATE_OPEN_BROWSER"] = "0"
      response = OpenInBrowserTool.call(file_path: file.path, server_context: {})
      data = JSON.parse(response.content.first[:text])
      assert_equal false, data["launched"]
      assert_equal false, called
    ensure
      BrowserOpener.define_singleton_method(:open, orig_open)
      file.unlink
    end
  end

  test "base URL respects DOCNOTATE_BASE_URL and strips trailing slash" do
    file = Tempfile.new([ "url_test", ".md" ])
    file.write("# URL Test")
    file.close

    ENV["DOCNOTATE_BASE_URL"] = "http://docnotate.mycompany.internal:8080/"
    response = OpenInBrowserTool.call(file_path: file.path, launch: false, server_context: {})
    data = JSON.parse(response.content.first[:text])

    assert_match(%r{\Ahttp://docnotate\.mycompany\.internal:8080/documents/open\?file_path=}, data["url"])
  ensure
    file.unlink
  end
end
