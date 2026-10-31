import { Controller } from "@hotwired/stimulus"
import { install, uninstall } from "@github/hotkey"
import { BLOCK_SELECTOR } from "utils/dom_selectors"

export default class extends Controller {
    static targets = ["source", "nav", "navCurrent", "navTotal", "inboxBadge", "previousButton", "nextButton"]
    static values = { remote: Boolean }

    connect() {
	this.comments = []
	this.commentsById = new Map()
	this.allMarks = []
	this.navigableComments = []
	this.currentCommentIndex = -1
	this.hotkeysInstalled = false

	this.markedIds = []
	this.contentEl = this.element.querySelector(".document__content")
	if (this.contentEl) {
		this.boundHandleMarkClick = this.handleMarkClick.bind(this)
		this.contentEl.addEventListener("click", this.boundHandleMarkClick)
	}

	this.loadComments()
    }

    disconnect() {
	this.contentEl?.removeEventListener("click", this.boundHandleMarkClick)
	if (this.hotkeysInstalled) {
		if (this.hasPreviousButtonTarget) uninstall(this.previousButtonTarget)
		if (this.hasNextButtonTarget) uninstall(this.nextButtonTarget)
		this.hotkeysInstalled = false
	}
    }

    loadComments() {
	if (!this.remoteValue) this.clearAllMarks()

	let payload = { current: [], archived: [] }
	try {
	    const parsed = JSON.parse(this.sourceTarget.textContent)
	    payload = Array.isArray(parsed) ? { current: parsed, archived: [] } : parsed
	} catch {
	    payload = { current: [], archived: [] }
	}

	this.comments = payload.current || []
	this.archivedComments = payload.archived || []
	this.unresolvedArchivedCount = this.archivedComments.filter(comment => !comment.is_resolved).length
	this.commentsById.clear()
	this.comments.forEach(comment => this.commentsById.set(comment.id, comment))
	if (this.remoteValue) {
		this.buildRemoteNavigable()
		this.updateNav()
		return
	}

	this.allMarks = []
	this.applyAllComments()
	this.buildNavigableComments()
	this.updateNav()
    }

    clearAllMarks() {
	this.allMarks.forEach(mark =>
	    mark.replaceWith(document.createTextNode(mark.textContent))
	)
	this.allMarks = []
	this.contentEl.normalize()
    }

    applyAllComments() {
	this.comments.forEach(comment => this.applyComment(comment))
    }

    applyComment(comment) {
	const startBlock = document.getElementById(comment.start_block_id)
	const endBlock = document.getElementById(comment.end_block_id)
	if (!startBlock || !endBlock) return

	const blocks = this.collectBlocksBetween(startBlock, endBlock)
	blocks.forEach((block, index) => {
	    const isFirst = index === 0
	    const isLast = index === blocks.length - 1
	    const blockTextLength = this.blockTextLength(block)

	    const from = isFirst ? comment.start_offset : 0
	    const to = isLast ? comment.end_offset : blockTextLength

	    if (from >= to) return

	    const marks = this.wrapTextRange(block, from, to, comment.id)
	    this.allMarks.push(...marks)
	})
    }

    collectBlocksBetween(startBlock, endBlock) {
	if (startBlock === endBlock) return [startBlock]

	const allBlocks = Array.from(this.contentEl.querySelectorAll(BLOCK_SELECTOR))
	const startIndex = allBlocks.indexOf(startBlock)
	const endIndex = allBlocks.indexOf(endBlock)

	if (startIndex === -1 || endIndex === -1) return []

	const rawSpan = allBlocks.slice(startIndex, endIndex + 1)
	return rawSpan.filter(block => !rawSpan.some(other => block !== other && block.contains(other)))
    }


    blockTextLength(blockEl) {
	const walker = document.createTreeWalker(blockEl, NodeFilter.SHOW_TEXT, null, false)
	let length = 0
	let node
	while ((node = walker.nextNode()) !== null) {
	    length += node.textContent.length
	}
	return length
    }

    wrapTextRange(rootEl, from, to, commentId) {
	const walker = document.createTreeWalker(rootEl, NodeFilter.SHOW_TEXT, null, false)
	const highlights = []
	let cursor = 0
	let textNode

	while ((textNode = walker.nextNode()) !== null) {
	    const nodeLength = textNode.textContent.length
	    const nodeStart = cursor
	    const nodeEnd = cursor + nodeLength

	    const overlapStart = Math.max(from, nodeStart)
	    const overlapEnd = Math.min(to, nodeEnd)

	    if (overlapStart < overlapEnd) {
		highlights.push({
		    textNode,
		    localStart: overlapStart - nodeStart,
		    localEnd: overlapEnd - nodeStart
		})
	    }

	    cursor += nodeLength
	}

	const marks = []
	highlights.forEach(({ textNode, localStart, localEnd }) => {
	    const parent = textNode.parentNode
	    textNode.splitText(localEnd)
	    const highlightedNode = textNode.splitText(localStart)
	    const mark = document.createElement("mark")

	    mark.className = "document__comment-highlight"
	    mark.dataset.commentId = commentId
	    mark.textContent = highlightedNode.textContent
	    parent.replaceChild(mark, highlightedNode)
	    marks.push(mark)
	})

	return marks
    }

    handleMarkClick(event) {
	const mark = event.target.closest(".document__comment-highlight")
	if (!mark) return

	this.openComment(Number(mark.dataset.commentId), mark.getBoundingClientRect())
    }

    openFromFrame(event) {
	this.openComment(event.detail.commentId, event.detail.rect)
    }

    openComment(commentId, rect) {
	const comment = this.commentsById.get(commentId)
	if (!comment) return

	this.showComment(comment, rect)

	const navIndex = this.navigableComments.findIndex(item => item.comment.id === commentId)
	if (navIndex !== -1) {
	    this.currentCommentIndex = navIndex
	    this.updateNav()
	}
    }

    buildNavigableComments() {
	this.navigableComments = this.comments
	    .map(comment => {
		const firstMark = this.allMarks.find(mark => Number(mark.dataset.commentId) === comment.id)
		return { comment, firstMark }
	    })
	    .filter(item => item.firstMark)

	this.navigableComments.sort((a, b) => {
	    if (a.firstMark === b.firstMark) return 0
	    const position = a.firstMark.compareDocumentPosition(b.firstMark)
	    return position & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1
	})

	this.currentCommentIndex = -1
    }

    receiveMarks(event) {
	this.markedIds = event.detail.markedIds
	this.buildRemoteNavigable()
	this.updateNav()
    }

    buildRemoteNavigable() {
	this.navigableComments = this.markedIds
	    .map(commentId => ({ comment: this.commentsById.get(commentId) }))
	    .filter(item => item.comment)
	this.currentCommentIndex = -1
    }

    updateNav() {
	const total = this.navigableComments.length
	this.navTotalTarget.textContent = total
	this.navCurrentTarget.textContent = total > 0 ? this.currentCommentIndex + 1 : 0
	this.navTarget.style.display = (total > 0 || this.archivedComments.length > 0) ? "flex" : "none"

	if (total > 0) {
		if (!this.hotkeysInstalled) {
			if (this.hasPreviousButtonTarget) install(this.previousButtonTarget)
			if (this.hasNextButtonTarget) install(this.nextButtonTarget)
			this.hotkeysInstalled = true
		}
	} else {
		if (this.hotkeysInstalled) {
			if (this.hasPreviousButtonTarget) uninstall(this.previousButtonTarget)
			if (this.hasNextButtonTarget) uninstall(this.nextButtonTarget)
			this.hotkeysInstalled = false
		}
	}

	if (this.hasInboxBadgeTarget) {
	    this.inboxBadgeTarget.textContent = this.unresolvedArchivedCount
	    this.inboxBadgeTarget.hidden = this.unresolvedArchivedCount === 0
	}
    }

    previousComment() {
	const baseIndex = this.currentCommentIndex === -1 ? 0 : this.currentCommentIndex
	this.goToComment(baseIndex - 1)
    }

    nextComment() {
	this.goToComment(this.currentCommentIndex + 1)
    }

    goToComment(index) {
	const count = this.navigableComments.length
	if (count === 0) return

	this.element.dispatchEvent(new CustomEvent("document-view:show-document", { bubbles: true }))

	this.currentCommentIndex = ((index % count) + count) % count
	const { comment, firstMark } = this.navigableComments[this.currentCommentIndex]

	const rect = this.scrollToComment(comment.id, firstMark)
	this.showComment(comment, rect)
	this.updateNav()
    }

    scrollToComment(commentId, firstMark) {
	if (this.remoteValue) {
		this.dispatch("scrollTo", { detail: { commentId } })
		return null
	}

	firstMark.scrollIntoView({ behavior: "smooth", block: "center" })
	return firstMark.getBoundingClientRect()
    }

    scrollToArchived() {
	this.dispatch("showArchived")
    }

    showComment(comment, rect) {
	this.activateMarks(comment.id)
	this.element.dispatchEvent(new CustomEvent("comment-highlight:show", {
	    detail: { comment, rect },
	    bubbles: true
	}))
    }

    // Marks of the open comment get the accent underline so the popover's subject
    // is identifiable at a glance among other highlighted comments
    activateMarks(commentId) {
	this.allMarks.forEach(mark =>
	    mark.classList.toggle("document__comment-highlight--active", Number(mark.dataset.commentId) === commentId)
	)
    }

    clearActiveMarks() {
	this.activateMarks(null)
    }

    reloadFromSource() {
	this.loadComments()
    }
}
