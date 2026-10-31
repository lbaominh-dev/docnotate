# frozen_string_literal: true

# Phase 1 placeholder tool: proves the full MCP loop (handshake → tools/list →
# tools/call) end-to-end before real domain tools land in later phases.

class AppStatusTool < MCP::Tool
  # Class names become underscored tool names by default (app_status_tool);
  # call-side names are the agents' surface, so expose the cleaner one.
  tool_name "app_status"
  title "App Status"
  description "Reports DocNotate's runtime status: whether the library is reachable and how many documents it holds. Use this first to verify the connection."

  # input_schema is JSON Schema — this is the contract agents read to decide
  # how to call the tool. `required` can be empty here.
  input_schema(
    properties: {
      include_details: {
        type: "boolean",
        description: "Include environment details (Rails env, protocol-level info).",
      },
    },
    required: [],
  )

  # MCP tool annotations are hints for agents, not enforcement: this tool only
  # reads, does not change the world if called twice.
  annotations(
    read_only_hint: true,
    destructive_hint: false,
    idempotent_hint: true,
    open_world_hint: false,
  )

  class << self
    def call(include_details: false, server_context:)
      doc_count = Current.user ? Current.user.documents.count : Document.count
      payload = {
        app: "DocNotate",
        status: "ok",
        documents_count: doc_count,
      }
      payload[:workspace] = Current.user.name if Current.user

      if include_details
        payload[:env] = Rails.env
        payload[:server_context] = server_context.transform_keys(&:to_s)
      end

      MCP::Tool::Response.new(
        [ { type: "text", text: JSON.pretty_generate(payload) } ],
      )
    end
  end
end
