# frozen_string_literal: true

class GetDocumentContentTool < MCP::Tool
  tool_name "get_document_content"
  title "Get Document Content"
  description "Returns the raw stored content of a document by id (the exact text of its latest parsed version: markdown or html source). Use this before editing content later; open_document is preferred for reading structure."

  input_schema(
    properties: {
      document_id: {
        type: "integer",
        description: "Document id as returned by list_documents or open_document.",
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
    def call(document_id:, server_context:)
      scope = Current.user ? Current.user.documents : Document
      document = scope.find(document_id)

      payload = {
        id: document.id,
        file_path: document.file_path,
        file_type: document.file_type,
        version: document.current_version&.version,
        content: document.content,
      }

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
