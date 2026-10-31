# frozen_string_literal: true

class ResolveCommentTool < MCP::Tool
  tool_name "resolve_comment"
  title "Resolve Comment"
  description "Marks a comment as resolved (or reopens it with resolved:false). Resolving means the feedback " +
    "was addressed — it stays in DocNotate as history rather than disappearing. " +
    "Only comments pinned to a previous document version can be resolved: current-version comments " +
    "(still under active discussion) cannot. get_document_comments shows which comments are resolvable — " +
    "entries under \"current\" are not, entries under \"archived\" are."

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
      resolved: {
        type: "boolean",
        default: true,
        description: "Pass false to reopen an already-resolved comment.",
      },
    },
    required: %w[document_id comment_id],
  )

  annotations(
    read_only_hint: false,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(document_id:, comment_id:, resolved: true, server_context:)
      scope = Current.user ? Current.user.documents : Document
      document = scope.find(document_id)
      comment = document.set_comment_resolved!(comment_id, resolved: resolved)

      state = comment.is_resolved ? "resolved" : "reopened"
      MCP::Tool::Response.new(
        [ { type: "text", text: "Comment #{comment.id} #{state} (version #{comment.document_version.version})." } ],
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [ { type: "text", text: "Not found (or the comment does not belong to document #{document_id})." } ],
        error: true,
      )
    rescue Documents::Commentable::UnresolvableComment => e
      MCP::Tool::Response.new(
        [ { type: "text", text: "#{e.message} — current-version comments stay open while the document is being discussed. Archive comments are resolvable." } ],
        error: true,
      )
    end
  end
end
