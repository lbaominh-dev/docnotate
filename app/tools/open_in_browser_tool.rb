# frozen_string_literal: true

class OpenInBrowserTool < MCP::Tool
  tool_name "open_in_browser"
  title "Open in Browser"
  description "Opens a document in DocNotate's web UI in the user's desktop browser. Accepts either file_path or document_id (exactly one required). Registers or resyncs the file if a path is provided. Always returns the full browser URL and launch status."

  input_schema(
    properties: {
      file_path: {
        type: "string",
        description: "Path of the file to open (absolute, or as shown by list_documents). Provide either file_path or document_id.",
      },
      document_id: {
        type: "integer",
        description: "Document id as returned by list_documents or read_document. Provide either file_path or document_id.",
      },
      launch: {
        type: "boolean",
        description: "Whether to launch the host desktop browser (default: true). Set false to suppress launch and only return the URL.",
      },
    },
  )

  annotations(
    read_only_hint: false,
    destructive_hint: false,
    idempotent_hint: false,
    open_world_hint: true,
  )

  class << self
    def call(file_path: nil, document_id: nil, launch: true, server_context:)
      document = Document.resolve_document(id: document_id, file_path: file_path)

      unless Document.supported_file?(document.file_path)
        return MCP::Tool::Response.new(
          [ { type: "text", text: "Unsupported file type for browser view: #{document.file_path}" } ],
          error: true,
        )
      end

      url = document.browser_url
      launch_requested = !launch.in?([ false, "false", 0, "0" ])
      launch_suppressed = ENV["DOCNOTATE_OPEN_BROWSER"].to_s.strip.downcase.in?(%w[false 0])
      should_launch = launch_requested && !launch_suppressed

      launched = false
      message = nil
      warning = nil

      if should_launch
        if BrowserOpener.open(url)
          launched = true
          message = "Opened in browser at #{url}"
        else
          launched = false
          message = "Could not launch desktop browser (no display or opener binary unavailable). Open the URL manually."
          warning = "Could not launch desktop browser (no display or opener binary unavailable). Open the URL manually."
        end
      else
        launched = false
        message = "Browser launch skipped. Open the URL manually."
      end

      payload = {
        document_id: document.id,
        name: document.display_name,
        file_path: document.file_path,
        url: url,
        launched: launched,
        message: message,
      }
      payload[:warning] = warning if warning.present?
      payload[:error] = warning if warning.present?

      MCP::Tool::Response.new(
        [ { type: "text", text: JSON.pretty_generate(payload) } ],
      )
    rescue ArgumentError => e
      error_message = e.message == "File does not exist" ? "File not found: #{file_path}" : e.message
      MCP::Tool::Response.new(
        [ { type: "text", text: error_message } ],
        error: true,
      )
    rescue ActiveRecord::RecordNotFound => e
      MCP::Tool::Response.new(
        [ { type: "text", text: e.message } ],
        error: true,
      )
    end
  end
end
