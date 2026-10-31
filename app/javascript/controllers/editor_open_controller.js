import { Controller } from "@hotwired/stimulus"
import {
  getStoredEditorSettings,
  saveStoredEditorSettings,
  resolveLocalFilePath,
  buildEditorUrl,
  triggerDeepLink
} from "utils/editor_deep_links"

export default class extends Controller {
  static targets = [
    "button", "panel", "form", "input", "error",
    "editorSelect", "workspaceInput", "customTemplateWrapper", "customTemplateInput", "previewUrl"
  ]

  static values = {
    cloud: Boolean,
    filePath: String
  }

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
    this.boundKeydown = this.keydown.bind(this)

    if (this.cloudValue) {
      const settings = getStoredEditorSettings()
      const isRelative = this.isPathRelative(this.filePathValue)
      this.configured = Boolean(settings.scheme && (!isRelative || settings.workspacePath))
    } else {
      this.configured = this.element.dataset.editorOpenConfigured === "true"
    }
  }

  disconnect() {
    this.removeDocumentListeners()
  }

  isPathRelative(path) {
    if (!path) return true
    return !path.startsWith("/") && !/^[A-Za-z]:[\\/]/.test(path)
  }

  open(event) {
    if (event && (event.shiftKey || event.altKey)) {
      this.openPanel()
      return
    }

    if (this.cloudValue) {
      if (this.configured) {
        this.openCloudDeepLink()
      } else {
        this.openPanel()
      }
    } else {
      if (this.configured) {
        this.openInEditor()
      } else {
        this.openPanel()
      }
    }
  }

  openPanel() {
    this.panelTarget.hidden = false
    this.setExpanded(true)
    this.addDocumentListeners()

    if (this.cloudValue) {
      this.loadCloudSettingsIntoForm()
      this.updatePreview()
      if (this.hasWorkspaceInputTarget && !this.workspaceInputTarget.value) {
        this.workspaceInputTarget.focus()
      } else if (this.hasEditorSelectTarget) {
        this.editorSelectTarget.focus()
      }
    } else if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  close() {
    if (this.panelTarget.hidden) return

    this.panelTarget.hidden = true
    this.setExpanded(false)
    this.removeDocumentListeners()
  }

  setExpanded(expanded) {
    this.buttonTargets.forEach(button => button.setAttribute("aria-expanded", String(expanded)))
  }

  loadCloudSettingsIntoForm() {
    const settings = getStoredEditorSettings()
    if (this.hasEditorSelectTarget && settings.scheme) {
      this.editorSelectTarget.value = settings.scheme
    }
    if (this.hasWorkspaceInputTarget) {
      this.workspaceInputTarget.value = settings.workspacePath || ""
    }
    if (this.hasCustomTemplateInputTarget) {
      this.customTemplateInputTarget.value = settings.customTemplate || ""
    }
  }

  updatePreview() {
    if (!this.cloudValue || !this.hasEditorSelectTarget) return

    const scheme = this.editorSelectTarget.value
    if (this.hasCustomTemplateWrapperTarget) {
      this.customTemplateWrapperTarget.hidden = (scheme !== "custom")
    }

    const workspacePath = this.hasWorkspaceInputTarget ? this.workspaceInputTarget.value : ""
    const customTemplate = this.hasCustomTemplateInputTarget ? this.customTemplateInputTarget.value : ""
    const resolvedPath = resolveLocalFilePath(workspacePath, this.filePathValue)
    const url = buildEditorUrl(scheme, resolvedPath, customTemplate)

    if (this.hasPreviewUrlTarget) {
      this.previewUrlTarget.textContent = url || "(configure path above)"
    }
  }

  saveAndOpenCloud(event) {
    event.preventDefault()

    const scheme = this.hasEditorSelectTarget ? this.editorSelectTarget.value : "vscode"
    const workspacePath = this.hasWorkspaceInputTarget ? this.workspaceInputTarget.value.trim() : ""
    const customTemplate = this.hasCustomTemplateInputTarget ? this.customTemplateInputTarget.value.trim() : ""

    if (this.isPathRelative(this.filePathValue) && !workspacePath) {
      this.showError("Please enter your local project root path to open relative files.")
      if (this.hasWorkspaceInputTarget) this.workspaceInputTarget.focus()
      return
    }

    saveStoredEditorSettings({ scheme, workspacePath, customTemplate })
    this.configured = true
    this.close()

    const resolvedPath = resolveLocalFilePath(workspacePath, this.filePathValue)
    const url = buildEditorUrl(scheme, resolvedPath, customTemplate)
    triggerDeepLink(url)
  }

  openCloudDeepLink() {
    const settings = getStoredEditorSettings()
    if (this.isPathRelative(this.filePathValue) && !settings.workspacePath) {
      this.openPanel()
      this.showError("Please enter your local project root path to locate this file.")
      return
    }

    const resolvedPath = resolveLocalFilePath(settings.workspacePath, this.filePathValue)
    const url = buildEditorUrl(settings.scheme, resolvedPath, settings.customTemplate)
    triggerDeepLink(url)
  }

  // --- Local Mode actions ---
  async choose(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const submitter = event.submitter
    if (submitter && submitter.name === "editor_name") {
      formData.set("editor_name", submitter.value)
    }

    await this.submit(formData)
  }

  async openInEditor() {
    await this.submit(new FormData())
  }

  async submit(formData) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    let response

    try {
      response = await fetch(this.url, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          ...(token ? { "X-CSRF-Token": token } : {})
        },
        body: formData
      })
    } catch {
      this.showError("Network error. Please try again.")
      return
    }

    if (response.ok) {
      this.close()
      this.configured = true
      this.element.dataset.editorOpenConfigured = "true"
    } else {
      const data = await response.json().catch(() => ({}))
      this.openPanel()
      this.showError(data.error || "Unable to open file in editor")
    }
  }

  get url() {
    return this.element.dataset.editorOpenUrl
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.hidden = false
    }
  }

  clickOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  keydown(event) {
    if (event.key === "Escape") this.close()
  }

  addDocumentListeners() {
    document.addEventListener("click", this.boundClickOutside)
    document.addEventListener("keydown", this.boundKeydown)
  }

  removeDocumentListeners() {
    document.removeEventListener("click", this.boundClickOutside)
    document.removeEventListener("keydown", this.boundKeydown)
  }
}
