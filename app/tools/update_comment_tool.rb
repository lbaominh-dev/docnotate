# frozen_string_literal: true

class UpdateCommentTool < MCP::Tool
  tool_name "update_comment"
  title "Update Comment"
  description "Replaces a comment's body text. Get current comment bodies from get_document_comments first. " +
    "The comment id can be read from the \"current\" list (or \"archived\" with its version)."

  input_schema(
    properties: {
      document_id: {
        type: "integer",
        description: "Document id the comment belongs to.",
      },
      comment_id: {
        type: "integer",
        description: "Comment id as returned by get_document_comments or create_comment.",
      },
      content: {
        type: "string",
        description: "New comment body text.",
      },
    },
    required: %w[document_id comment_id content],
  )

  annotations(
    read_only_hint: false,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(document_id:, comment_id:, content:, server_context:)
      scope = Current.user ? Current.user.documents : Document
      document = scope.find(document_id)
      comment = document.update_comment!(comment_id, content)

      MCP::Tool::Response.new(
        [ { type: "text", text: "Comment #{comment.id} updated.\n#{JSON.pretty_generate(comment.slice(:id, :content))}" } ],
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [ { type: "text", text: "Not found (or the comment does not belong to document #{document_id})." } ],
        error: true,
      )
    rescue ActiveRecord::RecordInvalid => e
      MCP::Tool::Response.new(
        [ { type: "text", text: "Comment not updated: #{e.record.errors.full_messages.to_sentence}" } ],
        error: true,
      )
    end
  end
end
