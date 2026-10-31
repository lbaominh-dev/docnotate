import { Controller } from "@hotwired/stimulus"
import { install, uninstall } from "@github/hotkey"
import { copyToClipboard } from "utils/clipboard"

export default class extends Controller {
    static targets = ["source", "button", "divider", "defaultIcon", "successIcon"]
    static values = { remote: Boolean }

    connect() {
        this.copyTimeout = null
        this.anchoredIds = []
        this.hotkeyInstalled = false
        this.loadComments()
    }

    disconnect() {
        if (this.copyTimeout) clearTimeout(this.copyTimeout)
        this.resetState()
        if (this.hotkeyInstalled) {
            uninstall(this.buttonTarget)
            this.hotkeyInstalled = false
        }
    }

    loadComments() {
        let payload = { current: [], archived: [] }
        try {
            const parsed = JSON.parse(this.sourceTarget.textContent)
            payload = Array.isArray(parsed) ? { current: parsed, archived: [] } : parsed
        } catch {
            payload = { current: [], archived: [] }
        }

        this.orderedComments = this.remoteValue
            ? this.orderRemoteComments(payload.current || [])
            : this.orderDomComments(payload.current || [])

        const visible = this.orderedComments.length > 0
        this.buttonTarget.style.display = visible ? "inline-flex" : "none"
        this.dividerTarget.style.display = visible ? "block" : "none"

        if (visible) {
            if (!this.hotkeyInstalled) {
                install(this.buttonTarget)
                this.hotkeyInstalled = true
            }
        } else {
            if (this.hotkeyInstalled) {
                uninstall(this.buttonTarget)
                this.hotkeyInstalled = false
            }
        }
    }

    receiveAnchors(event) {
        this.anchoredIds = event.detail.anchoredIds
        this.loadComments()
    }

    // Keep only current inline comments whose start block still exists in the DOM.
    // Archived/previous comments don't have a start_block_id, so they're ignored.
    orderDomComments(comments) {
        return comments
            .filter(comment => comment.start_block_id && document.getElementById(comment.start_block_id))
            .sort((a, b) => {
                const elA = document.getElementById(a.start_block_id)
                const elB = document.getElementById(b.start_block_id)
                if (elA === elB) return 0
                const position = elA.compareDocumentPosition(elB)
                return position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1
            })
    }

    // The frame owns the blocks, so it reports which comments are anchored, in document order
    orderRemoteComments(comments) {
        const rank = new Map(this.anchoredIds.map((id, index) => [id, index]))

        return comments
            .filter(comment => rank.has(comment.id))
            .sort((a, b) => rank.get(a.id) - rank.get(b.id))
    }

    async copyComments() {
        if (this.orderedComments.length === 0) return

        const text = this.orderedComments.map((comment, index) => {
            const selectedText = (comment.selected_text || "").trim()
            const content = (comment.content || "").trim()
            return `${index + 1}. "${selectedText}"\n> ${content}`
        }).join("\n\n")

        try {
            await copyToClipboard(text)
            this.flashCopied()
        } catch (error) {
            console.error("Failed to copy comments:", error)
        }
    }

    flashCopied() {
        this.buttonTarget.classList.add("document__comment-copy--copied")
        if (this.hasDefaultIconTarget && this.hasSuccessIconTarget) {
            this.defaultIconTarget.classList.add("document__comment-copy-icon--hidden")
            this.successIconTarget.classList.remove("document__comment-copy-icon--hidden")
        }
        this.buttonTarget.dataset.tooltip = "Copied!"
        this.buttonTarget.setAttribute("aria-label", "Copied!")

        if (this.copyTimeout) clearTimeout(this.copyTimeout)
        this.copyTimeout = setTimeout(() => this.resetState(), 1800)
    }

    resetState() {
        this.buttonTarget.classList.remove("document__comment-copy--copied")
        if (this.hasDefaultIconTarget && this.hasSuccessIconTarget) {
            this.defaultIconTarget.classList.remove("document__comment-copy-icon--hidden")
            this.successIconTarget.classList.add("document__comment-copy-icon--hidden")
        }
        this.buttonTarget.dataset.tooltip = "Copy comments (⇧⌘Y)"
        this.buttonTarget.setAttribute("aria-label", "Copy comments")
    }
}
