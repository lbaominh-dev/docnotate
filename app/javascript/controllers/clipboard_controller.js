import { Controller } from "@hotwired/stimulus"
import { copyToClipboard } from "utils/clipboard"

export default class extends Controller {
    static values = {
        text: String
    }

    static targets = ["defaultIcon", "successIcon"]

    async copy(event) {
        if (event) {
            event.preventDefault()
            event.stopPropagation()
        }

        try {
            await copyToClipboard(this.textValue)
            this.showSuccess()
        } catch (error) {
            console.error("Failed to copy to clipboard:", error)
        }
    }

    showSuccess() {
        if (!this.originalTooltip && this.element.dataset.tooltip) {
            this.originalTooltip = this.element.dataset.tooltip
        }
        this.element.dataset.tooltip = "Copied!"
        this.element.setAttribute("aria-label", "Copied!")

        this.defaultIconTarget.classList.add("document__copy-icon--hidden")
        this.successIconTarget.classList.remove("document__copy-icon--hidden")

        if (this.successTimeout) {
            clearTimeout(this.successTimeout)
        }

        this.successTimeout = setTimeout(() => {
            this.resetState()
        }, 2000)
    }

    resetState() {
        if (this.hasDefaultIconTarget && this.hasSuccessIconTarget) {
            this.defaultIconTarget.classList.remove("document__copy-icon--hidden")
            this.successIconTarget.classList.add("document__copy-icon--hidden")
        }
        if (this.originalTooltip) {
            this.element.dataset.tooltip = this.originalTooltip
        } else {
            delete this.element.dataset.tooltip
        }
        this.element.setAttribute("aria-label", "Copy file path")
    }

    disconnect() {
        if (this.successTimeout) {
            clearTimeout(this.successTimeout)
        }
        this.resetState()
    }
}
