import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel", "form", "input", "error"]

  connect() {
    this.boundClickOutside = this.clickOutside.bind(this)
    this.boundKeydown = this.keydown.bind(this)
  }

  disconnect() {
    this.removeDocumentListeners()
  }

  toggle() {
    if (this.panelTarget.hidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.panelTarget.hidden = false
    this.buttonTarget.setAttribute("aria-expanded", "true")
    this.addDocumentListeners()
    if (this.hasInputTarget) {
      this.inputTarget.focus()
    }
  }

  close() {
    if (this.panelTarget.hidden) return

    this.panelTarget.hidden = true
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.removeDocumentListeners()
  }

  async save(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const submitter = event.submitter
    if (submitter && submitter.name === "editor_name") {
      formData.set("editor_name", submitter.value)
    }

    const token = document.querySelector('meta[name="csrf-token"]')?.content
    let response

    try {
      response = await fetch(this.formTarget.action, {
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
    } else {
      const data = await response.json().catch(() => ({}))
      this.showError(data.error || "Unable to save settings")
    }
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
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
