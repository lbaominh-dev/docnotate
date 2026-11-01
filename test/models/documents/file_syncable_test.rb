# frozen_string_literal: true

require "test_helper"

class Documents::FileSyncableTest < ActiveSupport::TestCase
  setup do
    @orig_base_url = ENV["DOCNOTATE_BASE_URL"]
    @orig_root_url = ENV["DOCNOTATE_ROOT_URL"]
    @orig_port = ENV["PORT"]
    ENV.delete("DOCNOTATE_BASE_URL")
    ENV.delete("DOCNOTATE_ROOT_URL")
    ENV.delete("PORT")
    AppSetting.find_by(key: "base_url")&.destroy
  end

  teardown do
    ENV["DOCNOTATE_BASE_URL"] = @orig_base_url if @orig_base_url
    ENV["DOCNOTATE_ROOT_URL"] = @orig_root_url if @orig_root_url
    ENV["PORT"] = @orig_port if @orig_port
    AppSetting.find_by(key: "base_url")&.destroy
  end

  test "browser_base_url follows strict precedence hierarchy" do
    # Default fallback: Puma port 3000
    assert_equal "http://localhost:3000", Document.browser_base_url

    # PORT env override
    ENV["PORT"] = "4000"
    assert_equal "http://localhost:4000", Document.browser_base_url

    # AppSetting base_url in DB overrides PORT
    AppSetting.set("base_url", "http://myhost:5000/")
    assert_equal "http://myhost:5000", Document.browser_base_url

    # DOCNOTATE_ROOT_URL overrides DB
    ENV["DOCNOTATE_ROOT_URL"] = "http://myhost:6000/"
    assert_equal "http://myhost:6000", Document.browser_base_url

    # DOCNOTATE_BASE_URL overrides DOCNOTATE_ROOT_URL
    ENV["DOCNOTATE_BASE_URL"] = "http://myhost:7000/"
    assert_equal "http://myhost:7000", Document.browser_base_url
  end

  test "browser_url URI-encodes file paths with spaces" do
    doc = Document.new(file_path: "/Users/test/My Documents/My Plan.md")
    expected = "http://localhost:3000/documents/open?file_path=%2FUsers%2Ftest%2FMy%20Documents%2FMy%20Plan.md"
    assert_equal expected, doc.browser_url
  end

  test "resolve_document raises ArgumentError when both id and file_path are given" do
    error = assert_raises(ArgumentError) do
      Document.resolve_document(id: 1, file_path: "/path/to/doc.md")
    end
    assert_equal "Provide either file_path or document_id, not both.", error.message
  end

  test "resolve_document raises ArgumentError when neither id nor file_path is given" do
    error = assert_raises(ArgumentError) do
      Document.resolve_document
    end
    assert_equal "Either file_path or document_id is required.", error.message
  end

  test "resolve_document finds existing document by id" do
    file = Tempfile.new([ "test", ".md" ])
    file.write("# Test")
    file.close

    doc = Document.open(file.path)
    resolved = Document.resolve_document(id: doc.id)
    assert_equal doc.id, resolved.id
  ensure
    file.unlink
  end

  test "resolve_document raises ActiveRecord::RecordNotFound when id is missing" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Document.resolve_document(id: 999_999)
    end
  end

  test "resolve_document opens document by file_path" do
    file = Tempfile.new([ "test", ".md" ])
    file.write("# Test Plan")
    file.close

    doc = Document.resolve_document(file_path: file.path)
    assert_equal File.realpath(file.path), doc.file_path
  ensure
    file.unlink
  end
end
