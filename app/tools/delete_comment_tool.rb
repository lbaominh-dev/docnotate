# frozen_string_literal: true

class DeleteCommentTool < MCP::Tool
  tool_name "delete_comment"
  title "Delete Comment"
  description "Deletes one comment (removes the comment record; works on both current and archived comments). " +
    "Read comments and their ids from get_document_comments first. This is not the same as resolving — " +
    "resolving keeps the comment as settled feedback, deleting removes it entirely, so only delete " +
    "when the user clearly asked to remove a comment."

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
    },
    required: %w[document_id comment_id],
  )

  annotations(
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(document_id:, comment_id:, server_context:)
      scope = Current.user ? Current.user.documents : Document
      document = scope.find(document_id)
      comment = document.destroy_comment!(comment_id)

      MCP::Tool::Response.new(
        [ { type: "text", text: "Comment #{comment_id} deleted from document #{document_id} (\"#{comment.content.to_s.truncate(80)}\")." } ],
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [ { type: "text", text: "Not found (or the comment does not belong to document #{document_id})." } ],
        error: true,
      )
    end
  end
end
