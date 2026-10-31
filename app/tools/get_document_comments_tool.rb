# frozen_string_literal: true

class GetDocumentCommentsTool < MCP::Tool
  tool_name "get_document_comments"
  title "Get Document Comments"
  description "Returns a document's inline comments, including the selected text and block span each comment anchors to (block ids come from open_document's outline). " +
    "Only comments on the current version arrive inline; comments pinned to older versions come back under \"archived\" with the version they belong to. " +
    "Default status is \"unresolved\" — pass \"all\" to include already-resolved comments too."

  input_schema(
    properties: {
      document_id: {
        type: "integer",
        description: "Document id as returned by list_documents or open_document.",
      },
      status: {
        type: "string",
        enum: %w[unresolved resolved all],
        description: "Filter by resolution state. Omit for unresolved only.",
      },
    },
    required: %w[document_id],
  )

  annotations(
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(document_id:, status: "unresolved", server_context:)
      scope = Current.user ? Current.user.documents : Document
      document = scope.find(document_id)
      status = "all" unless %w[unresolved resolved all].include?(status)
      comments = document.comments_payload(status: status)

      payload = {
        document_id: document.id,
        file_path: document.file_path,
        status: status,
        current: comments[:current],
        archived: comments[:archived],
      }

      payload[:current_version] = document.current_version&.version

      MCP::Tool::Response.new(
        [ { type: "text", text: JSON.pretty_generate(payload) } ],
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [ { type: "text", text: "Document not found: id #{document_id}" } ],
        error: true,
      )
    end
  end
end
