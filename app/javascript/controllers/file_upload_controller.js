import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form", "fileName", "content", "dropzone", "status"]

  connect() {
    this.syncClientHistory()
  }

  trigger() {
    this.inputTarget.click()
  }

  async handleFile(event) {
    const file = event.target.files?.[0]
    if (!file) return

    await this.processFile(file)
  }

  dragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.add("file-dropzone--active")
    }
  }

  dragLeave(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove("file-dropzone--active")
    }
  }

  async drop(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.hasDropzoneTarget) {
      this.dropzoneTarget.classList.remove("file-dropzone--active")
    }

    const file = event.dataTransfer?.files?.[0]
    if (!file) return

    await this.processFile(file)
  }

  async processFile(file) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = `Reading ${file.name}...`
      this.statusTarget.style.display = "block"
    }

    try {
      const textContent = await file.text()

      // Save record in local storage history
      this.saveToClientHistory(file.name, file.size)

      this.fileNameTarget.value = file.name
      this.contentTarget.value = textContent

      if (this.hasStatusTarget) {
        this.statusTarget.textContent = `Opening ${file.name}...`
      }

      this.formTarget.requestSubmit()
    } catch (error) {
      console.error("Error reading file:", error)
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = `Failed to read file: ${error.message}`
      }
    }
  }

  saveToClientHistory(fileName, size) {
    try {
      const key = "docnotate_client_recent_files"
      const existing = JSON.parse(localStorage.getItem(key) || "[]")
      const updated = [
        { name: fileName, size: size, opened_at: new Date().toISOString() },
        ...existing.filter(f => f.name !== fileName)
      ].slice(0, 10)
      localStorage.setItem(key, JSON.stringify(updated))
    } catch (e) {
      // Local storage unavailable or full
    }
  }

  syncClientHistory() {
    // Expose client history for quick access
    try {
      const history = JSON.parse(localStorage.getItem("docnotate_client_recent_files") || "[]")
      if (history.length > 0) {
        window.__docnotateClientHistory = history
      }
    } catch (e) {}
  }
}
