require "application_system_test_case"

class MarkdownDocumentsSystemTest < ApplicationSystemTestCase
  setup do
    @file = Tempfile.new([ "wide-markdown", ".md" ])
    @file.write(<<~MARKDOWN)
      # Release overview

      Prose remains a comfortable reading width while tables and diagrams can use the surrounding space.

      - Review the release checklist.
      - Keep annotations beside their source.

      > The reading column also applies to quotations.

      | Status | Owner |
      | --- | --- |
      | Ready | Platform |

      | Service | Owner | Region | Status | Latency | Traffic | Errors | Capacity | Version | Decision |
      | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
      | Gateway | Platform | Europe | Ready | 42 ms | 1200 rpm | 0.02% | 65% | 3.8.1 | Approved |

      ```mermaid
      flowchart LR
        A[Client request] --> B[Edge gateway] --> C[Authentication] --> D[Request routing] --> E[Background worker] --> F[Persistent storage] --> G[Audit reporting]
      ```

      ```mermaid
      flowchart TD
        A[Review] --> B[Approve]
      ```
    MARKDOWN
    @file.close
  end

  teardown do
    @file.unlink
  end

  test "reading view is the default and wide view expands blocks without widening prose" do
    page.current_window.resize_to(1440, 1000)
    visit open_documents_path(file_path: @file.path)
    assert_selector ".document__mermaid-canvas > svg", count: 2

    reading_width = find("#document_paper").rect.width
    assert_operator reading_width, :<, 900
    assert_selector "button[aria-label='Wide view'][aria-pressed='false']"
    find("button[aria-label='Wide view']").click
    assert_selector "button[aria-label='Wide view'][aria-pressed='true']"
    assert_operator find("#document_paper").rect.width, :>, 1200

    prose = first(".document__content > p").rect
    assert_operator prose.width, :<=, 700
    assert_in_delta page.evaluate_script("document.documentElement.clientWidth / 2"), prose.x + prose.width / 2, 2
    assert_operator all("table")[0].rect.width, :<, prose.width
    assert_operator all("table")[1].rect.width, :>, prose.width * 1.5
    assert_operator all(".document__mermaid-canvas > svg")[0].rect.width, :>, prose.width * 1.5
    assert_operator all(".document__mermaid-canvas > svg")[1].rect.width, :<, prose.width

    find("button[aria-label='Wide view']").send_keys(:space)
    assert_selector "button[aria-label='Wide view'][aria-pressed='false']"
    assert_in_delta reading_width, find("#document_paper").rect.width, 1
    find("button[aria-label='Wide view']").click

    [ 900, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      assert_equal width, page.evaluate_script("window.innerWidth")
      assert_no_horizontal_page_overflow
      assert_operator first(".document__content > p").rect.width, :<=, 700
      assert page.evaluate_script("document.querySelectorAll('table')[1].scrollWidth > document.querySelectorAll('table')[1].clientWidth")
      all(".document__mermaid-canvas > svg").each do |diagram|
        assert_operator diagram.rect.x + diagram.rect.width, :<=, width
      end
    end

    find("button[aria-label='Wide view']").click
    assert_no_horizontal_page_overflow
    find("button[aria-label='Wide view']").click
    assert_selector "button[aria-label='Wide view'][aria-pressed='true']"
    refresh
    assert_selector "button[aria-label='Wide view'][aria-pressed='false']"
  end

  test "comments on the right edge of a wide table remain accessible and anchored" do
    page.current_window.resize_to(1440, 1000)
    visit open_documents_path(file_path: @file.path)
    assert_selector ".document__mermaid-canvas > svg", count: 2
    find("button[aria-label='Wide view']").click

    page.execute_script(<<~JS)
      const table = document.querySelectorAll("table")[1]
      table.scrollLeft = table.scrollWidth
      const cell = table.querySelector("tbody td:last-child")
      const walker = document.createTreeWalker(cell, NodeFilter.SHOW_TEXT)
      let text
      while ((text = walker.nextNode()) && !text.textContent.includes("Approved")) {}
      const range = document.createRange()
      const start = text.textContent.indexOf("Approved")
      range.setStart(text, start)
      range.setEnd(text, start + "Approved".length)
      window.getSelection().removeAllRanges()
      window.getSelection().addRange(range)
      cell.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }))
    JS
    assert_selector ".document__selection-toolbar"
    assert_no_horizontal_page_overflow
    click_button "Add Note"
    assert_selector ".document__comment-card"
    card = find(".document__comment-card").rect
    assert_operator card.x + card.width, :<=, 1440
    fill_in "comment_create_text", with: "Confirm the final approval."
    within ".document__comment-card" do
      click_button "Comment"
    end
    assert_selector "td:last-child .document__comment-highlight", text: "Approved"

    refresh
    assert_selector "td:last-child .document__comment-highlight", text: "Approved", visible: :all
    find("button[aria-label='Wide view']").click
    [ 1440, 390 ].each do |width|
      page.current_window.resize_to(width, 1000)
      page.execute_script("const table = document.querySelectorAll('table')[1]; table.scrollLeft = table.scrollWidth")
      page.execute_script("document.querySelector('td:last-child .document__comment-highlight').scrollIntoView({ block: 'center' })")
      find("td:last-child .document__comment-highlight").click
      assert_selector ".document__comment-popover", text: "Confirm the final approval."
      popover = find(".document__comment-popover").rect
      assert_operator popover.x, :>=, 0
      assert_operator popover.x + popover.width, :<=, width
      assert_no_horizontal_page_overflow
      find(".document__comment-popover button[aria-label='Close']").click
    end
  end

  test "toggles between document content and previous comments" do
    visit open_documents_path(file_path: @file.path)
    document = Document.find_by!(file_path: File.realpath(@file.path))
    first_version = document.current_version
    first_version.comments.create!(content: "Note from previous version")

    @file.open
    @file.write("# Updated Overview\n\nNew paragraph content.")
    @file.close

    visit open_documents_path(file_path: @file.path)

    assert_selector ".document__content", visible: true
    assert_selector ".document__archived-panel", visible: false

    find(".document__comment-inbox-button").click

    assert_selector ".document__comment-inbox-button[aria-pressed='true'][aria-label='Back to document']"
    assert_selector ".document__content", visible: false
    assert_selector ".document__archived-panel", visible: true
    assert_text "Note from previous version"

    find(".document__comment-inbox-button").click

    assert_selector ".document__comment-inbox-button[aria-pressed='false'][aria-label='Previous comments']"
    assert_selector ".document__content", visible: true
    assert_selector ".document__archived-panel", visible: false
  end

  test "syntax highlights code blocks while keeping comments anchored and interactive" do
    code_file = Tempfile.new([ "code-sample", ".md" ])
    code_file.write(<<~MARKDOWN)
      # Code Example

      ```ruby
      def calculate_total(items)
        items.sum(&:price)
      end
      ```

      ```
      plain text block without fence language
      ```

      ```customlang
      unknown language block
      ```

      ```mermaid
      flowchart TD
        A --> B
      ```
    MARKDOWN
    code_file.close

    visit open_documents_path(file_path: code_file.path)

    assert_selector "pre code.language-ruby[data-highlighted='true']"
    assert_selector "pre code.language-ruby .hljs-keyword", text: "def"
    assert_selector "pre code.language-ruby .hljs-title.function_", text: "calculate_total"

    # Untagged block should be processed via highlightAuto
    assert_selector "pre code:not([class*='language-'])[data-highlighted='true']", text: /plain text block/

    # Unknown language block should be marked highlighted but left without syntax spans
    assert_selector "pre code.language-customlang[data-highlighted='true']", text: /unknown language block/
    assert_no_selector "pre code.language-customlang span[class^='hljs-']"

    assert_selector ".document__mermaid-canvas > svg"
    assert_no_selector "pre code.language-mermaid[data-highlighted='true']"

    document = Document.find_by!(file_path: File.realpath(code_file.path))
    version = document.current_version
    code_node = version.document_nodes.find_by!(node_type: "code_block")

    start_offset = code_node.content.index("calculate_total")
    end_offset = start_offset + "calculate_total".length
    version.comments.create!(
      content: "Ensure this handles empty lists.",
      start_block_id: code_node.node_id,
      end_block_id: code_node.node_id,
      start_offset: start_offset,
      end_offset: end_offset
    )

    refresh

    assert_selector "pre code.language-ruby[data-highlighted='true']"
    assert_selector "pre code.language-ruby .document__comment-highlight", text: "calculate_total"

    find("pre code.language-ruby .document__comment-highlight").click
    assert_selector ".document__comment-popover", text: "Ensure this handles empty lists."
  ensure
    code_file.unlink
  end

  test "multi-block comment selection across paragraphs and list" do
    page.current_window.resize_to(1440, 1000)
    visit open_documents_path(file_path: @file.path)

    page.execute_script(<<~JS)
      const p = document.querySelector(".document__content > p")
      const li = document.querySelector(".document__content li")

      const pWalker = document.createTreeWalker(p, NodeFilter.SHOW_TEXT)
      const pText = pWalker.nextNode()

      const liWalker = document.createTreeWalker(li, NodeFilter.SHOW_TEXT)
      const liText = liWalker.nextNode()

      const range = document.createRange()
      range.setStart(pText, 10)
      range.setEnd(liText, 15)

      window.getSelection().removeAllRanges()
      window.getSelection().addRange(range)
      p.dispatchEvent(new MouseEvent("mouseup", { bubbles: true }))
    JS


    assert_selector ".document__selection-toolbar"
    click_button "Add Note"
    assert_selector ".document__comment-card"
    fill_in "comment_create_text", with: "Cross-block comment note"
    within ".document__comment-card" do
      click_button "Comment"
    end

    assert_selector ".document__comment-highlight", minimum: 2

    refresh

    assert_selector ".document__comment-highlight", minimum: 2
    first(".document__comment-highlight").click
    assert_selector ".document__comment-popover", text: "Cross-block comment note"
  end



  private

  def assert_no_horizontal_page_overflow
    assert page.evaluate_script("document.documentElement.scrollWidth <= document.documentElement.clientWidth")
  end
end
