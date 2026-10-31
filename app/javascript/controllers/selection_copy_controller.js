import { Controller } from "@hotwired/stimulus"
import { copyToClipboard } from "utils/clipboard"

export default class extends Controller {
    static values = { text: String }
    static targets = ["defaultIcon", "successIcon"]

    connect() {
        this.copyTimeout = null
    }

    disconnect() {
        if (this.copyTimeout) clearTimeout(this.copyTimeout)
    }

    async copy(event) {
        event.preventDefault()
        event.stopPropagation()

        const text = this.textValue
        if (!text) return

        try {
            await copyToClipboard(text)
            this.flash()
        } catch (error) {
            console.error("Failed to copy selected text:", error)
        }
    }

    flash() {
        this.defaultIconTarget.classList.add("document__selection-copy-icon--hidden")
        this.successIconTarget.classList.remove("document__selection-copy-icon--hidden")

        if (this.copyTimeout) clearTimeout(this.copyTimeout)
        this.copyTimeout = setTimeout(() => this.reset(), 2000)
    }

    reset() {
        if (this.copyTimeout) clearTimeout(this.copyTimeout)
        this.copyTimeout = null

        this.defaultIconTarget.classList.remove("document__selection-copy-icon--hidden")
        this.successIconTarget.classList.add("document__selection-copy-icon--hidden")
    }
}
