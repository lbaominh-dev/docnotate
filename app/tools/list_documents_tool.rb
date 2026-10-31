# frozen_string_literal: true

class ListDocumentsTool < MCP::Tool
  tool_name "list_documents"
  title "List Documents"
  description "Lists documents in DocNotate's library with id, name, file path, file type, and when each was last opened. Filter by a title/file-path match and/or file type. Returns ids and file paths that the other docnotate tools use."

  input_schema(
    properties: {
      query: {
        type: "string",
        description: "Case-insensitive match on document name or file path. Omit to list all.",
      },
      file_type: {
        type: "string",
        enum: %w[markdown html],
        description: "Only list documents of this file type. Omit for all types.",
      },
    },
    required: [],
  )

  annotations(
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(query: nil, file_type: nil, server_context:)
      scope = Current.user ? Current.user.documents : Document
      documents = scope.matching_title(query.to_s).with_file_type(file_type).order(:file_path)

      payload = {
        count: documents.count,
        documents: documents.map do |document|
          {
            id: document.id,
            name: document.display_name,
            file_path: document.file_path,
            file_type: document.file_type,
            last_opened_at: document.last_opened_at&.iso8601,
          }
        end,
      }

      MCP::Tool::Response.new(
        [ { type: "text", text: JSON.pretty_generate(payload) } ],
      )
    end
  end
end
