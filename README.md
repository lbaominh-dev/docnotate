# DocNotate

## Contents

- [Introduction](#introduction)
- [Demo](#demo)
- [Features](#features)
- [Keybindings](#keybindings)
- [Installation](#installation)
  - [Run locally](#run-locally)
  - [Run with Docker](#run-with-docker)
- [Tech stack](#tech-stack)
- [MCP server](#mcp-server)
- [Credits](#credits)

## Introduction

DocNotate is a web-based Rails application designed to solve a major pain point in the age of AI-driven development.

When you're using AI agents to build features day by day, efficiency is everything. Usually, you plan the workflow with the agent beforehand, and the agent generates a markdown file outlining the full plan. To ensure everything is on track, you have to review and validate that plan. But what happens when you disagree with a specific part?

Normally, you'd have to stop reading, copy the problematic section, paste it into the AI console, and tell the agent to fix it. This constant back-and-forth causes massive context switching. But if you wait until the end, you'll probably forget half of your feedback.

That's where DocNotate comes in. It lets you open any markdown file — or an HTML document, rendered as a web page — in a clean, read-only view, with more formats coming soon. As you read, if you spot something you want to change or clarify, just highlight the text, add an inline comment, and keep reading. Once you're done, hit the copy button to grab all your comments and their corresponding code snippets at once. Then, just paste the whole thing into your AI console to get everything fixed in one single prompt.

## Demo
<img width="1256" height="653" alt="image" src="https://github.com/user-attachments/assets/7fd6e2ec-a4ef-4d12-8a33-78e2bac07176" />


<img width="1342" height="905" alt="image" src="https://github.com/user-attachments/assets/9111e5e1-c702-4237-8106-d8b8818eaecf" />

<img width="1347" height="904" alt="image" src="https://github.com/user-attachments/assets/761ee354-79dc-4b43-b9e1-318cff573175" />


<!-- TODO: add demo video -->

## Features

- Open any local markdown file (HTML support included) in a clean, read-only view
- Highlight text and leave inline comments that stay anchored to the content
- Copy all comments with their surrounding snippets in one click
- Comment inbox to review, edit, and resolve comments as they get fixed
- Table of contents with quick navigation
- Markdown extras: tables and syntax highlighting
- Mermaid diagrams rendered as interactive SVG with zoom and pan, an expand button for a wide modal view, and a graceful fallback to the raw source on errors
- All-files page to browse, rename, delete, and revisit recently opened documents
- Open a document in your preferred editor directly from the app

## Keybindings

Keyboard shortcuts available across DocNotate:

| Keybinding | Description |
| --- | --- |
| ⌘B | Toggle file sidebar |
| ⌘/ | With text selected: open comment input |
| ⌘↵ | In comment form: submit new comment |
| ⌘↵ | In comment popover: save edited comment |
| ⌘K | In document view: jump to previous comment |
| ⌘J | In document view: jump to next comment |
| ⇧⌘Y | In document view: copy comments to clipboard |
| ⇧⌘" / ⇧⌘' / ⌘" | In document view: view previous comments |
| ⌥⌘S | In previous comments: toggle resolve all |
| ⇧⌘X | In markdown view: toggle wide view |
| ⇧⌘L | In document view: copy file path |
| ⌘E | In document view: open in editor |
| ⇧⌘D | In comment popover: delete comment |
| Esc | Close active sidebar, panel, or modal |
| Esc | In comment popover: cancel edit or close |
| Esc | When renaming: cancel document rename |

## Installation

### Run locally

Requires [Ruby](https://www.ruby-lang.org/) 4.0 (any version manager works — `.tool-versions` is included).

```bash
git clone https://github.com/tortoise10h/docnotate.git
cd docnotate
bin/setup
```

That's it — `bin/setup` installs dependencies, prepares the SQLite database, and starts the server. Open http://localhost:3535 and open a file by its path.

To start the server again later, run:

```bash
bin/dev
```

### Run with Docker

*A Docker image isn't finalized yet — we'll finalize the Dockerfile and update this section later.*

## Tech stack

DocNotate is deliberately lightweight:

- **Vanilla Rails 8** with ERB templates — no frontend framework
- **Hotwire** (Turbo + Stimulus) for the interactive bits
- **SQLite** as the only database, and the Solid suite (cache, queue, cable) running on it
- **No Node build step** — JavaScript is served via importmap
- Everything runs on your machine against your local files — no accounts, no external services

## MCP server

DocNotate ships a [Model Context Protocol](https://modelcontextprotocol.io) server at `http://localhost:3535/mcp`. Point your agent (pi, Claude Code, OpenCode, Cursor, etc.) at it and the agent can read your inline comments on any document you're reviewing, fix the plan file directly, mark comments resolved — or open a document, comment on it, and rename or remove it from history. Every conversation reads from the same live app you use.

```json
{
  "mcpServers": {
    "docnotate": {
      "url": "http://localhost:3535/mcp"
    }
  }
}
```

Set this up in the MCP config of your agent harness with the Dev server running (`bin/dev`). All tools operate on your own local files — there is no auth because everything stays on localhost.

| Tool | What it does |
| --- | --- |
| `app_status` | App connectivity check |
| `list_documents` | List documents in the library |
| `open_document` | Open (or re-sync) a file by path and get its id |
| `get_document_content` | Read a document's full current text |
| `get_document_comments` | Read inline comments, optionally filtered by status |
| `create_comment` | Add an inline comment, optionally anchored by `selected_text` |
| `update_comment` | Edit a comment's content |
| `delete_comment` | Remove a comment |
| `resolve_comment` | Mark a comment resolved (or reopen it) |
| `rename_document` | Change a document's display name |
| `delete_document` | Remove a document from history, without ever touching the file |

## Credits

DocNotate's product philosophy is inspired by [Basecamp](https://basecamp.com) and [Zed](https://zed.dev): simple and intuitive over complex and fancy — just make it work and be friendly. The UI style borrows a lot from Zed's documentation.
