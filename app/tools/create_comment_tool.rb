# frozen_string_literal: true

class CreateCommentTool < MCP::Tool
  tool_name "create_comment"
  title "Create Comment"
  description "Anchors a new inline comment on the document's current version. " +
    "Two ways to anchor: pass selected_text (text you took from read_document's outline — the span is located for you), " +
    "or pass the block span yourself (start_block_id/end_block_id, optionally the offsets). Passing both is fine; " +
    "an explicit span wins. prefix_text/postfix_text give the anchor's surrounding text, like a quote's context. " +
    "Returns the created comment with its id — use that id later with resolve_comment/update_comment/delete_comment " +
    "and note the user sees it on their next view of the document."

  input_schema(
    properties: {
      document_id: {
        type: "integer",
        description: "Document id as returned by list_documents or read_document.",
      },
      content: {
        type: "string",
        description: "The comment body shown to the user.",
      },
      selected_text: {
        type: "string",
        description: "Exact text from the document to anchor on. Must match one block's text in the current version.",
      },
      start_block_id: {
        type: "string",
        description: "block_id of the first block in the span (from read_document's outline).",
      },
      end_block_id: {
        type: "string",
        description: "block_id of the last block in the span.",
      },
      start_offset: { type: "integer" },
      end_offset: { type: "integer" },
      prefix_text: { type: "string", description: "Short text right before the selection." },
      postfix_text: { type: "string", description: "Short text right after the selection." },
    },
    required: %w[document_id content],
  )

  annotations(
    read_only_hint: false,
    destructive_hint: false,
    idempotent_hint: false,
    open_world_hint: false,
  )

  class << self
    # Optional anchor fields come in (or not) as keyword arguments from the
    # agent, so they need explicit nil defaults here.
    def call(document_id:, content:, selected_text: nil, start_block_id: nil,
             end_block_id: nil, start_offset: nil, end_offset: nil,
             prefix_text: nil, postfix_text: nil, server_context:)
      document = Document.find(document_id)
      comment = document.create_comment!(
        content: content,
        selected_text: selected_text,
        start_block_id: start_block_id,
        end_block_id: end_block_id,
        start_offset: start_offset,
        end_offset: end_offset,
        prefix_text: prefix_text,
        postfix_text: postfix_text,
      )

      anchor_summary = comment.start_block_id ? " anchored on block #{comment.start_block_id}" : ""
      MCP::Tool::Response.new(
        [ { type: "text", text: "Comment created (id #{comment.id}, version #{comment.document_version.version})#{anchor_summary}.\n#{JSON.pretty_generate(comment.slice(:id, :content, :selected_text, :start_block_id, :end_block_id, :start_offset, :end_offset, :prefix_text, :postfix_text))}" } ],
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [ { type: "text", text: "Document not found: id #{document_id}" } ],
        error: true,
      )
    rescue ActiveRecord::RecordInvalid => e
      MCP::Tool::Response.new(
        [ { type: "text", text: "Comment not saved: #{e.record.errors.full_messages.to_sentence}" } ],
        error: true,
      )
    end
  end
end
