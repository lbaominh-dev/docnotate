require "test_helper"

class DocumentsTest < ActionDispatch::IntegrationTest
  test "lists all files with pagination" do
    documents = 21.times.map do |index|
      create_document("document-#{index}.md", last_opened_at: Time.current - index.minutes)
    end

    get documents_path

    assert_response :success
    assert_select ".documents__row", count: 20
    assert_select ".documents__name", text: documents.first.display_name
    assert_select ".documents__name", text: documents.last.display_name, count: 0

    get documents_path, params: { page: 2 }

    assert_response :success
    assert_select ".documents__row", count: 1
    assert_select ".documents__name", text: documents.last.display_name
  end

  test "renames a document without changing its file path" do
    document = create_document("original.md")
    original_path = document.file_path

    patch document_path(document), params: { document: { name: "New name" } }

    assert_redirected_to documents_path
    assert_equal "File renamed", flash[:notice]
    assert_equal "New name", document.reload.name
    assert_equal original_path, document.file_path

    get documents_path

    assert_select ".documents__name", text: "New name"
  end

  test "renames a document via turbo stream" do
    document = create_document("rename-me.md")

    patch document_path(document), params: { document: { name: "New name" } }, as: :turbo_stream

    assert_response :ok
    assert_match %r{text/vnd.turbo-stream.html}, response.content_type
    assert_equal "New name", document.reload.name
    assert_match %r{action="replace" target="document_#{document.id}"}, response.body
    assert_match %r{action="replace" target="title_document_#{document.id}"}, response.body
    assert_match "New name", response.body
  end

  test "renders rename controls on document show page and updates title via turbo stream" do
    file = Tempfile.new([ "show-rename", ".md" ])
    file.write("# Heading")
    file.close

    get open_documents_path, params: { file_path: file.path }
    assert_response :success
    document = Document.find_by!(file_path: File.realpath(file.path))

    assert_select "#title_document_#{document.id}[data-controller='rename']"
    assert_select "button[data-action='click->rename#edit']"
    assert_select "form.document__rename-form[action=?]", document_path(document)

    patch document_path(document), params: { document: { name: "Updated title" } }, as: :turbo_stream

    assert_response :ok
    assert_equal "Updated title", document.reload.name
    assert_match %r{action="replace" target="title_document_#{document.id}"}, response.body
    assert_match "Updated title", response.body
  ensure
    file&.unlink
  end

  test "removes a document and its history without deleting the file" do
    file = Tempfile.new([ "remove-me", ".md" ])
    file.write("# Heading\n\nParagraph")
    file.close
    get open_documents_path, params: { file_path: file.path }
    document = Document.find_by!(file_path: File.realpath(file.path))
    version = document.current_version
    node_id = version.document_nodes.first.id
    comment = version.comments.create!(content: "A saved note")
    assert_not_empty version.document_nodes

    delete document_path(document)

    assert_redirected_to documents_path
    assert_equal "Removed from history", flash[:notice]
    assert_not Document.exists?(document.id)
    assert_not DocumentVersion.exists?(version.id)
    assert_not DocumentNode.exists?(node_id)
    assert_not Comment.exists?(comment.id)
    assert File.exist?(file.path)
  ensure
    file&.unlink
  end

  test "removes a document via turbo stream" do
    document = create_document("remove-me.md")

    assert_difference("Document.count", -1) do
      delete document_path(document), as: :turbo_stream
    end

    assert_response :ok
    assert_match %r{text/vnd.turbo-stream.html}, response.content_type
    assert_match %r{action="remove" target="document_#{document.id}"}, response.body
    assert_match %r{action="update" target="documents_count"}, response.body
    assert_match "(#{ActionController::Base.helpers.pluralize(Document.count, 'file')})", response.body
  end

  test "opens a document from a local file path" do
    file = Tempfile.new([ "sample", ".md" ])
    file.write("# Hello")
    file.close

    get open_documents_path, params: { file_path: file.path }

    document = Document.find_by(file_path: File.realpath(file.path))
    assert document.present?
    assert_response :success
    assert_select ".document__title", File.basename(file.path)
    assert_select ".document__editor [data-editor-open-target='button']"
    assert_select "[data-editor-open-configured='false']"
  ensure
    file.unlink
  end

  test "wires document-view panels for document content and previous comments in markdown" do
    file = Tempfile.new([ "sample", ".md" ])
    file.write("# Hello\n\nParagraph")
    file.close

    get open_documents_path, params: { file_path: file.path }
    document = Document.find_by!(file_path: File.realpath(file.path))
    first_version = document.current_version
    first_version.comments.create!(content: "Archived note")

    File.write(file.path, "# Hello\n\nUpdated paragraph")
    get open_documents_path, params: { file_path: file.path }

    assert_response :success
    assert_select "#document_paper[data-controller~='document-view']"
    assert_select "#document_paper .document__content[data-document-view-target='panel'][data-view='document']"
    assert_select "#document_paper .document__archived-panel[data-document-view-target='panel'][data-view='archived']"
    assert_select "#document_paper .document__archived-panel #previous-comments"
    assert_select ".document__comment-inbox-button[data-controller='hotkey']"
    assert_select ".document__width-toggle[data-controller='hotkey']"
    assert_select "#previous-comments button[data-controller='hotkey']"
  ensure
    file.unlink
  end

  test "renders file sidebar toggle button and panel in document view without scanning filesystem initially" do
    file = Tempfile.new([ "sample", ".md" ])
    file.write("# Hello")
    file.close

    original_scan = Filesystem::DirectoryScanner.method(:scan)
    scanned = false
    Filesystem::DirectoryScanner.define_singleton_method(:scan) do |*args|
      scanned = true
      original_scan.call(*args)
    end

    begin
      get open_documents_path, params: { file_path: file.path }
    ensure
      Filesystem::DirectoryScanner.define_singleton_method(:scan, original_scan)
      file.unlink
    end

    assert_response :success
    assert_not scanned, "Expected DirectoryScanner.scan not to be called on page load"
    assert_select ".document__sidebar-button[data-hotkey='Mod+b']"
    assert_select "button[data-controller~='clipboard'][data-controller~='hotkey'][data-hotkey='Mod+Shift+l,Mod+Shift+L'][data-tooltip='Copy file path (⇧⌘L)']"
    assert_select "aside.document__sidebar#document_sidebar[hidden]"
    assert_select "turbo-frame#document_sidebar_tree"
    assert_select "turbo-frame#document_sidebar_tree[src]", count: 0
    assert_select "turbo-frame#document_sidebar_tree[data-src*='filesystem']"
  end

  test "renders markdown tables" do
    file = Tempfile.new([ "table", ".md" ])
    file.write("| Name | Status |\n| --- | --- |\n| Alice | Active |")
    file.close

    get open_documents_path, params: { file_path: file.path }

    assert_response :success
    assert_select "table.document-node--table"
    assert_select "table > thead > tr.document-node--table-row"
    assert_select "table > tbody > tr.document-node--table-row"
    assert_select "thead th.document-node--table-cell-th", text: "Name"
    assert_select "tbody td.document-node--table-cell", text: "Active"
  ensure
    file.unlink
  end

  test "renders mermaid code blocks with the mermaid language class" do
    file = Tempfile.new([ "diagram", ".md" ])
    file.write("```mermaid\nflowchart TD\n  A --> B\n```")
    file.close

    get open_documents_path, params: { file_path: file.path }

    assert_response :success
    assert_select "pre.document-node--code-block code.language-mermaid", /flowchart TD/
    assert_select "dialog.mermaid-modal"
  ensure
    file.unlink
  end

  test "renders code blocks with language class when tagged and without language class when untagged" do
    file = Tempfile.new([ "code-blocks", ".md" ])
    file.write("```ruby\ndef greet; puts 'hi'; end\n```\n\n```\nplain text\n```")
    file.close

    get open_documents_path, params: { file_path: file.path }

    assert_response :success
    assert_select "pre.document-node--code-block code.language-ruby", text: /def greet/
    assert_select "pre.document-node--code-block code:not([class*='language-'])", text: /plain text/
  ensure
    file.unlink
  end

  test "resolves a relative file path to an absolute path" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        File.write("relative.md", "# Hello")

        get open_documents_path, params: { file_path: "relative.md" }

        assert_response :success
        document = Document.find_by(file_path: File.realpath("relative.md", dir))
        assert document.present?
      end
    end
  end

  test "does not bump version when file has not changed" do
    file = Tempfile.new([ "sample", ".md" ])
    file.write("# Hello")
    file.close

    get open_documents_path, params: { file_path: file.path }
    document = Document.find_by(file_path: File.realpath(file.path))
    first_version = document.current_version.version

    get open_documents_path, params: { file_path: file.path }
    document.reload

    assert_equal first_version, document.current_version.version
  ensure
    file.unlink
  end

  test "replaces stale document nodes when the file is updated" do
    file = Tempfile.new([ "sample", ".md" ])
    file.write("# Hello")
    file.close

    get open_documents_path, params: { file_path: file.path }
    document = Document.find_by(file_path: File.realpath(file.path))
    first_version = document.current_version.version
    first_node_count = document.document_nodes.count

    sleep 1
    File.write(file.path, "# World")
    get open_documents_path, params: { file_path: file.path }
    document.reload

    assert_not_equal first_version, document.current_version.version
    assert_equal first_node_count, document.document_nodes.count,
                 "re-parsing should replace stale nodes, not stack new ones on top"
    assert_equal "# World", document.content
    text_nodes = document.document_nodes.where(node_type: "text").pluck(:content)
    assert_includes text_nodes, "World"
    assert_not_includes text_nodes, "Hello", "stale node from previous version should be removed"
  ensure
    file.unlink
  end

  test "redirects home when file path is blank" do
    get open_documents_path

    assert_redirected_to root_path
    assert_equal "No file provided", flash[:alert]
  end

  test "redirects home when file does not exist" do
    get open_documents_path, params: { file_path: "/non/existent/file.md" }

    assert_redirected_to root_path
    assert_equal "File not found", flash[:alert]
  end

  test "renders unsupported file error for non-markdown files" do
    file = Tempfile.new([ "sample", ".txt" ])
    file.write("Hello")
    file.close

    get open_documents_path, params: { file_path: file.path }

    assert_response :unsupported_media_type
    assert_select ".error__title", "Unsupported file type"
    assert_select ".error__message", /#{File.basename(file.path)}/
    assert_select "a[href=?]", root_path, text: /Return to Home/
  ensure
    file.unlink
  end

  test "renders editor open button in local mode" do
    file = Tempfile.new([ "local-editor-test", ".md" ])
    file.write("# Heading\nLocal test")
    file.close

    get open_documents_path, params: { file_path: file.path }
    assert_response :success
    assert_select ".document__editor[data-editor-open-cloud-value='false']"
    assert_select "button[data-editor-open-target='button']"
    assert_select "input[name='editor_name']"
  ensure
    file&.unlink
  end

  test "renders editor open button and deep link config in cloud mode" do
    orig_mode = ENV["DOCNOTATE_MODE"]
    ENV["DOCNOTATE_MODE"] = "cloud"

    begin
      file = Tempfile.new([ "cloud-editor-test", ".md" ])
      file.write("# Heading\nCloud test")
      file.close

      get open_documents_path, params: { file_path: file.path }
      assert_response :success
      assert_select ".document__editor[data-editor-open-cloud-value='true']"
      assert_select "button[data-editor-open-target='button']"
      assert_select "select[data-editor-open-target='editorSelect']"
      assert_select "input[data-editor-open-target='workspaceInput']"
      assert_select "code[data-editor-open-target='previewUrl']"
    ensure
      ENV["DOCNOTATE_MODE"] = orig_mode
      file&.unlink
    end
  end

  private

  def create_document(file_path, last_opened_at: Time.current)
    Document.create!(
      file_path: "/tmp/#{file_path}",
      content: "# #{file_path}",
      file_type: "markdown",
      last_opened_at: last_opened_at
    )
  end
end
