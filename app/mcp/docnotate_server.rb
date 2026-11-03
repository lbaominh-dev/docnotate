# frozen_string_literal: true

# DocNotate's MCP server assembly.
#
# Referenced from config/routes.rb — routes load after initialization, so the
# tool classes under app/tools are autoloadable by the time the server is
# built (they are not available in config/initializers).
#
# MCP::Server only stores metadata and tool classes; it knows nothing about
# transports. The transport is created in routes.rb and mounted as a Rack app
# at /mcp, which is why the same server could later be driven over stdio.

DocnotateServer = MCP::Server.new(
  name: "docnotate",
  title: "DocNotate",
  description: "MCP server for DocNotate: lets agents plan in documents, read inline comments, and address feedback.",
  version: "1.0.0",
  tools: [
    AppStatusTool,
    ListDocumentsTool,
    ReadDocumentTool,
    OpenInBrowserTool,
    GetDocumentContentTool,
    GetDocumentCommentsTool,
    CreateCommentTool,
    UpdateCommentTool,
    DeleteCommentTool,
    ResolveCommentTool,
    RenameDocumentTool,
    DeleteDocumentTool,
  ],
  server_context: { app_name: "DocNotate" },
)
