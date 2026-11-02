import { Controller } from "@hotwired/stimulus"
import { copyToClipboard } from "utils/clipboard"
import { loadWorkspaces, rememberWorkspace, forgetWorkspace, maskedToken } from "utils/workspace_store"

export default class extends Controller {
  static targets = [
    "modal",
    "copyStatus",
    "savedList",
    "dropdownButton",
    "dropdownMenu",
    "dropdownList",
    "dropdownCount",
    "switchForm",
    "switchTokenInput"
  ]
  static values = {
    token: String,
    name: String,
    url: String
  }

  connect() {
    if (this.tokenValue) {
      rememberWorkspace({ token: this.tokenValue, name: this.nameValue })
    }

    this.renderWorkspaces()
    this.onDocumentClick = this.closeDropdownOnOutsideClick.bind(this)
    this.onDocumentKeydown = this.closeDropdownOnEscape.bind(this)
    document.addEventListener("click", this.onDocumentClick)
    document.addEventListener("keydown", this.onDocumentKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    document.removeEventListener("keydown", this.onDocumentKeydown)
  }

  open() {
    this.closeDropdown()
    if (this.hasModalTarget) {
      this.modalTarget.showModal()
    }
  }

  close() {
    if (this.hasModalTarget) {
      this.modalTarget.close()
    }
  }

  backdropClick(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  toggleDropdown(event) {
    event.stopPropagation()
    if (!this.hasDropdownMenuTarget) return

    const willOpen = this.dropdownMenuTarget.hidden
    this.dropdownMenuTarget.hidden = !willOpen
    if (this.hasDropdownButtonTarget) {
      this.dropdownButtonTarget.setAttribute("aria-expanded", String(willOpen))
    }
  }

  closeDropdown() {
    if (this.hasDropdownMenuTarget) {
      this.dropdownMenuTarget.hidden = true
    }
    if (this.hasDropdownButtonTarget) {
      this.dropdownButtonTarget.setAttribute("aria-expanded", "false")
    }
  }

  closeDropdownOnOutsideClick(event) {
    if (!this.hasDropdownMenuTarget || this.dropdownMenuTarget.hidden) return
    if (!this.isInsideDropdown(event.target)) this.closeDropdown()
  }

  closeDropdownOnEscape(event) {
    if (event.key !== "Escape" || !this.hasDropdownMenuTarget || this.dropdownMenuTarget.hidden) return

    this.closeDropdown()
    if (this.hasDropdownButtonTarget) this.dropdownButtonTarget.focus()
  }

  isInsideDropdown(node) {
    return (this.hasDropdownButtonTarget && this.dropdownButtonTarget.contains(node)) ||
      (this.hasDropdownMenuTarget && this.dropdownMenuTarget.contains(node))
  }

  switchWorkspace(event) {
    const token = event.currentTarget.dataset.workspaceToken
    if (!token) return

    this.closeDropdown()

    if (token === this.tokenValue) return

    if (this.hasSwitchTokenInputTarget && this.hasSwitchFormTarget) {
      this.switchTokenInputTarget.value = token
      this.switchFormTarget.requestSubmit()
    }
  }

  forget(event) {
    event.stopPropagation()
    const token = event.currentTarget.dataset.workspaceToken
    if (!token || token === this.tokenValue) return

    forgetWorkspace(token)
    this.renderWorkspaces()
  }

  renderWorkspaces() {
    const workspaces = loadWorkspaces()

    if (this.hasSavedListTarget) {
      this.renderSavedList(workspaces)
    }
    if (this.hasDropdownListTarget) {
      this.renderDropdownList(workspaces)
    }
    if (this.hasDropdownCountTarget) {
      this.dropdownCountTarget.textContent = workspaces.length
    }
  }

  renderSavedList(workspaces) {
    const items = workspaces.map(workspace => {
      const isCurrent = workspace.token === this.tokenValue
      const item = document.createElement("li")
      item.className = "workspace-list__item"
      if (isCurrent) item.classList.add("workspace-list__item--current")

      const info = document.createElement("div")
      info.className = "workspace-list__info"

      const name = document.createElement("span")
      name.className = "workspace-list__name"
      name.textContent = workspace.name

      const meta = document.createElement("span")
      meta.className = "workspace-list__meta"
      meta.textContent = maskedToken(workspace.token)

      info.append(name, meta)
      item.append(info)

      const actions = document.createElement("div")
      actions.className = "workspace-list__actions"

      if (isCurrent) {
        const badge = document.createElement("span")
        badge.className = "workspace-list__badge"
        badge.textContent = "Current"
        actions.append(badge)
      } else {
        const switchButton = document.createElement("button")
        switchButton.type = "button"
        switchButton.className = "button button--secondary workspace-list__switch"
        switchButton.textContent = "Switch"
        switchButton.dataset.workspaceToken = workspace.token
        switchButton.dataset.action = "click->workspace-modal#switchWorkspace"

        const removeButton = document.createElement("button")
        removeButton.type = "button"
        removeButton.className = "icon-button workspace-list__remove"
        removeButton.setAttribute("aria-label", `Remove ${workspace.name} from this browser`)
        removeButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>'
        removeButton.dataset.workspaceToken = workspace.token
        removeButton.dataset.action = "click->workspace-modal#forget"

        actions.append(switchButton, removeButton)
      }

      item.append(actions)
      return item
    })

    const emptyState = document.createElement("li")
    emptyState.className = "workspace-list__empty"
    emptyState.textContent = "No saved workspaces yet."

    this.savedListTarget.replaceChildren(...(items.length ? items : [emptyState]))
  }

  renderDropdownList(workspaces) {
    const items = workspaces.map(workspace => {
      const isCurrent = workspace.token === this.tokenValue
      const item = document.createElement(isCurrent ? "div" : "button")
      item.className = "workspace-switcher__item"
      if (isCurrent) item.classList.add("workspace-switcher__item--current")
      if (!isCurrent) {
        item.type = "button"
        item.dataset.workspaceToken = workspace.token
        item.dataset.action = "click->workspace-modal#switchWorkspace"
      }

      const name = document.createElement("span")
      name.className = "workspace-switcher__item-name"
      name.textContent = workspace.name

      const meta = document.createElement("span")
      meta.className = "workspace-switcher__item-meta"
      meta.textContent = isCurrent ? "Current" : maskedToken(workspace.token)

      item.append(name, meta)
      return item
    })

    this.dropdownListTarget.replaceChildren(...items)
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
      await copyToClipboard(config)
      this.showCopied("Config JSON Copied!")
    } catch (e) {
      console.error("Clipboard copy failed", e)
    }
  }

  async copyMcpUrl() {
    const origin = window.location.origin
    const mcpUrl = `${origin}/mcp?token=${this.tokenValue}`

    try {
      await copyToClipboard(mcpUrl)
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
