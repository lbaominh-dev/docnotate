# frozen_string_literal: true

class OpenDocumentTool < MCP::Tool
  tool_name "open_document"
  title "Open Document"
  description "Opens a markdown or html file by path (or syncs content directly). DocNotate reads it from disk or from database/content payload, upserts its record, and snapshots a new version if the file changed since last time — the same write path the app's UI uses. Returns the document's metadata and a block-level content outline; block ids double as comment anchors for comment tools."

  input_schema(
    properties: {
      file_path: {
        type: "string",
        description: "Path of the file to open (absolute, or as shown by list_documents).",
      },
      content: {
        type: "string",
        description: "Optional raw content to sync directly into DocNotate (useful when agent is remote or working with client-side files).",
      },
    },
    required: %w[file_path],
  )

  annotations(
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(file_path:, content: nil, server_context:)
      document = Document.open(file_path, content: content, user: Current.user)

      payload = {
        id: document.id,
        name: document.display_name,
        file_path: document.file_path,
        file_type: document.file_type,
        version: document.current_version&.version,
        last_opened_at: document.last_opened_at&.iso8601,
        content_outline: document.content_outline,
      }

      MCP::Tool::Response.new(
        [ { type: "text", text: JSON.pretty_generate(payload) } ],
      )
    rescue ArgumentError
      MCP::Tool::Response.new(
        [ { type: "text", text: "File not found: #{file_path}" } ],
        error: true,
      )
    end
  end
end
