import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "tokenInput", "copyStatus"]
  static values = {
    token: String,
    url: String
  }

  connect() {
    if (this.tokenValue) {
      try {
        localStorage.setItem("docnotate_workspace_token", this.tokenValue)
      } catch (e) {}
    }
  }

  open() {
    if (this.hasModalTarget) {
      this.modalTarget.showModal()
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.close()
    }
  }

  async copyMcpConfig() {
    const origin = window.location.origin
    const mcpUrl = `${origin}/mcp?token=${this.tokenValue}`
    const config = JSON.stringify({
      mcpServers: {
        docnotate: {
          url: mcpUrl
        }
      }
    }, null, 2)

    try {
      await navigator.clipboard.writeText(config)
      this.showCopied("Config JSON Copied!")
    } catch (e) {
      console.error("Clipboard copy failed", e)
    }
  }

  async copyMcpUrl() {
    const origin = window.location.origin
    const mcpUrl = `${origin}/mcp?token=${this.tokenValue}`

    try {
      await navigator.clipboard.writeText(mcpUrl)
      this.showCopied("MCP URL Copied!")
    } catch (e) {
      console.error("Clipboard copy failed", e)
    }
  }

  showCopied(message) {
    if (this.hasCopyStatusTarget) {
      this.copyStatusTarget.textContent = message
      this.copyStatusTarget.style.display = "inline-block"
      setTimeout(() => {
        this.copyStatusTarget.style.display = "none"
      }, 2500)
    }
  }
}
