# frozen_string_literal: true

class RenameDocumentTool < MCP::Tool
  tool_name "rename_document"
  title "Rename Document"
  description "Changes a document's display name inside DocNotate — the same thing the UI's rename does. " +
    "This does NOT rename the real file on disk — the file's location and base name stay as they are. Passing an empty name " +
    "falls back to the file's base name, so not passing name isn't an option here."

  input_schema(
    properties: {
      document_id: {
        type: "integer",
        description: "Document id as returned by list_documents or open_document.",
      },
      name: {
        type: "string",
        description: "New display name.",
      },
    },
    required: %w[document_id name],
  )

  annotations(
    read_only_hint: false,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(document_id:, name:, server_context:)
      scope = Current.user ? Current.user.documents : Document
      document = scope.find(document_id)
      document.update!(name: name)

      MCP::Tool::Response.new(
        [ { type: "text", text: "Document #{document_id} renamed to \"#{name}\" (disk file unchanged: #{document.file_path})." } ],
      )
    rescue ActiveRecord::RecordNotFound
      MCP::Tool::Response.new(
        [ { type: "text", text: "Document not found: id #{document_id}" } ],
        error: true,
      )
    rescue ActiveRecord::RecordInvalid => e
      MCP::Tool::Response.new(
        [ { type: "text", text: "Rename not saved: #{e.record.errors.full_messages.to_sentence}" } ],
        error: true,
      )
    end
  end
end
