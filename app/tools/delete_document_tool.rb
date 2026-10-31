# frozen_string_literal: true

class DeleteDocumentTool < MCP::Tool
  tool_name "delete_document"
  title "Delete Document"
  description "Removes a document from DocNotate's library (the UI's \"Removed from history\"): its record, version " +
    "history and comments are deleted. It NEVER deletes the real file on disk — the file stays exactly where it is; " +
    "opening it again recreates the entry (without old comments). Cleanup of the actual file stays a human decision: " +
    "if the user wants the file gone from disk they say so — deleting the record is not that. " +
    "Prefer delete over move only when the user wants the document out of DocNotate's history."

  input_schema(
    properties: {
      document_id: {
        type: "integer",
        description: "Document id as returned by list_documents.",
      },
    },
    required: %w[document_id],
  )

  annotations(
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(document_id:, server_context:)
      scope = Current.user ? Current.user.documents : Document
      document = scope.find(document_id)
      file_path = document.file_path
      document.destroy!

      MCP::Tool::Response.new(
        [ { type: "text", text: "Document #{document_id} (\"#{File.basename(file_path)}\") removed from DocNotate history. The file itself is untouched on disk: #{file_path}." } ],
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [ { type: "text", text: "Document not found: id #{document_id}" } ],
        error: true,
      )
    end
  end
end
