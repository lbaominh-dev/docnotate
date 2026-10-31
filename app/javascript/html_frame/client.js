// In-frame half of the HTML viewer bridge. HtmlFrameDocument serves it inside the sandboxed
// iframe right after utils/text_anchors.js, so it must not import anything. The parent page owns
// all UI and state; this script only marks text and reports geometry through postMessage.

const BLOCK_SELECTOR = "[data-docnotate-block]"
const HEADING_TAG_PATTERN = /^H[1-6]$/
const READY_RETRY_MS = 250
const READY_MAX_ATTEMPTS = 40
const KEEP_VISIBLE_MARGIN = 220

let activeMarks = []
let commentMarks = []
let focusedCommentId = null
let focusedMarkIndex = 0
let readyAcked = false
let reportScheduled = false

const style = document.createElement("style")
style.textContent = [
  "mark.document__selection-highlight { background: #5fd47e; border-radius: 2px; color: inherit; padding: 0; }",
  "mark.document__comment-highlight { background: #5fd47e; border-bottom: 2px solid #2e8b4a; border-radius: 2px; color: inherit; padding: 0; cursor: pointer; transition: background-color 0.15s ease; }",
  "mark.document__comment-highlight:hover { background: #4dbb6a; }",
  // SVG "marks" are rects painted under the text, so fill plays the background role
  "rect.document__selection-highlight { fill: #5fd47e; }",
  "rect.document__comment-highlight { fill: #5fd47e; cursor: pointer; }",
  "rect.document__comment-highlight:hover { fill: #4dbb6a; }",
  "@media (prefers-color-scheme: dark) {",
  "  mark.document__selection-highlight { background: rgba(46, 139, 74, 0.45); }",
  "  mark.document__comment-highlight { background: rgba(46, 139, 74, 0.45); border-bottom-color: #34d399; }",
  "  mark.document__comment-highlight:hover { background: rgba(46, 139, 74, 0.65); }",
  "  rect.document__selection-highlight { fill: rgba(46, 139, 74, 0.45); }",
  "  rect.document__comment-highlight { fill: rgba(46, 139, 74, 0.45); }",
  "  rect.document__comment-highlight:hover { fill: rgba(46, 139, 74, 0.65); }",
  "}",
  "[data-theme='dark'] mark.document__selection-highlight { background: rgba(46, 139, 74, 0.45); }",
  "[data-theme='dark'] mark.document__comment-highlight { background: rgba(46, 139, 74, 0.45); border-bottom-color: #34d399; }",
  "[data-theme='dark'] mark.document__comment-highlight:hover { background: rgba(46, 139, 74, 0.65); }",
  "[data-theme='dark'] rect.document__selection-highlight { fill: rgba(46, 139, 74, 0.45); }",
  "[data-theme='dark'] rect.document__comment-highlight { fill: rgba(46, 139, 74, 0.45); }",
  "[data-theme='dark'] rect.document__comment-highlight:hover { fill: rgba(46, 139, 74, 0.65); }"
].join("\n")
document.head.append(style)

function postToParent(message) {
    window.parent.postMessage(message, "*")
}

function selectedBlocks(range) {
    return selectedLeafBlocks(blockElements(), range)
}

function blockElements() {
    return Array.from(document.querySelectorAll(BLOCK_SELECTOR))
}

function markRects() {
    return activeMarks
        .flatMap(mark => Array.from(mark.getClientRects()))
        .map(({ left, top, right, bottom }) => ({ left, top, right, bottom }))
}

// Selections inside SVG text produce no marks, so fall back to the native range
// geometry to keep the toolbar anchored; the range survives removeAllRanges().
function rangeRects(range) {
    return Array.from(range.getClientRects())
        .map(({ left, top, right, bottom }) => ({ left, top, right, bottom }))
}

function rectOf(element) {
    const { left, top, right, bottom } = element.getBoundingClientRect()
    return { left, top, right, bottom }
}

function clearSelection() {
    unwrapHighlights(activeMarks, document.body)
    activeMarks = []
}

function handleMouseUp() {
    const selection = window.getSelection()
    const selectedText = selection.toString().trim()
    if (!selectedText || selection.rangeCount === 0) return

    const range = selection.getRangeAt(0)
    const blocks = selectedBlocks(range)
    if (blocks.length === 0 || range.getClientRects().length === 0) return

    const prefixText = extractPrefix(range)
    const postfixText = extractPostfix(range)
    const { startOffset, endOffset } = computeBlockOffsets(range, blocks[0], blocks[blocks.length - 1])

    clearSelection()
    activeMarks = highlightRange(range, document.body)
    selection.removeAllRanges()
    keepSelectionVisible()

    postToParent({
        type: "docnotate:selection",
        blockIds: blocks.map(blockIdOf),
        startOffset,
        endOffset,
        selectedText,
        prefixText,
        postfixText,
        rects: activeMarks.length > 0 ? markRects() : rangeRects(range)
    })
}

// The toolbar and comment card sit in the parent, so a selection near the bottom of the
// frame would push them out of view; scroll the selection up first.
function keepSelectionVisible() {
    const last = markRects().at(-1)
    if (last && last.bottom > window.innerHeight - KEEP_VISIBLE_MARGIN) {
        window.scrollBy(0, last.bottom - window.innerHeight / 3)
    }
}

// Mirrors comment_highlight_controller#applyComment so frame marks match markdown marks.
// Keep the nested double-mark behavior of that algorithm; do not "fix" it here.
function applyComments(comments) {
    unwrapHighlights(commentMarks, document.body)
    commentMarks = []

    const blocks = blockElements()
    const blocksById = new Map(blocks.map(block => [blockIdOf(block), block]))
    const anchored = []
    const firstMarkById = new Map()

    comments.forEach(comment => {
        const startBlock = blocksById.get(comment.start_block_id)
        const endBlock = blocksById.get(comment.end_block_id)
        if (!startBlock || !endBlock) return

        anchored.push({ id: comment.id, startBlock })
        const marks = applyCommentMarks(comment, blocks, startBlock, endBlock)
        commentMarks.push(...marks)
        if (marks.length > 0) firstMarkById.set(comment.id, marks[0])
    })

    anchored.sort((a, b) => documentOrder(a.startBlock, b.startBlock))
    const markedIds = anchored
        .map(({ id }) => id)
        .filter(id => firstMarkById.has(id))
        .sort((a, b) => documentOrder(firstMarkById.get(a), firstMarkById.get(b)))

    postToParent({
        type: "docnotate:marksApplied",
        markedIds,
        anchoredIds: anchored.map(({ id }) => id)
    })
    applyFocusedMarkClass()
    reportFocusedMark()
}

function applyCommentMarks(comment, blocks, startBlock, endBlock) {
    const span = blocksBetween(blocks, startBlock, endBlock)

    return span.flatMap((block, index) => {
        const from = index === 0 ? comment.start_offset : 0
        const to = index === span.length - 1 ? comment.end_offset : textLength(block)
        if (from >= to) return []

        return wrapTextRange(block, from, to, comment.id)
    })
}

function blocksBetween(blocks, startBlock, endBlock) {
    if (startBlock === endBlock) return [startBlock]

    const startIndex = blocks.indexOf(startBlock)
    const endIndex = blocks.indexOf(endBlock)
    if (startIndex === -1 || endIndex === -1) return []

    return blocks.slice(startIndex, endIndex + 1)
}

function textLength(root) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false)
    let length = 0
    let node
    while ((node = walker.nextNode()) !== null) {
        length += node.textContent.length
    }
    return length
}

function wrapTextRange(root, from, to, commentId) {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null, false)
    const pieces = []
    let cursor = 0
    let textNode

    while ((textNode = walker.nextNode()) !== null) {
        // SVG text can't hold HTML marks, but still counts toward cursor offsets so
        // block-relative offsets stay consistent with the selection that created them.
        if (textNode.parentNode.closest("svg")) {
            cursor += textNode.textContent.length
            continue
        }

        const nodeLength = textNode.textContent.length
        const overlapStart = Math.max(from, cursor)
        const overlapEnd = Math.min(to, cursor + nodeLength)

        if (overlapStart < overlapEnd) {
            pieces.push({ textNode, localStart: overlapStart - cursor, localEnd: overlapEnd - cursor })
        }
        cursor += nodeLength
    }

    return pieces.flatMap(({ textNode, localStart, localEnd }) => {
        if (textNode.parentNode.namespaceURI === "http://www.w3.org/2000/svg") {
            return highlightSvgTextNode(textNode, localStart, localEnd, "document__comment-highlight", commentId)
        }

        const parent = textNode.parentNode
        textNode.splitText(localEnd)
        const highlighted = textNode.splitText(localStart)
        const mark = document.createElement("mark")

        mark.className = "document__comment-highlight"
        mark.dataset.commentId = commentId
        mark.textContent = highlighted.textContent
        parent.replaceChild(mark, highlighted)
        return mark
    })
}

function documentOrder(a, b) {
    if (a === b) return 0
    return a.compareDocumentPosition(b) & Node.DOCUMENT_POSITION_FOLLOWING ? -1 : 1
}

function marksFor(commentId) {
    return commentMarks.filter(mark => Number(mark.dataset.commentId) === commentId)
}

// The popover follows the mark the user opened, so remember which mark of the comment that was.
function focusComment(commentId) {
    if (commentId !== focusedCommentId) focusedMarkIndex = 0
    focusedCommentId = commentId
    applyFocusedMarkClass()
    reportFocusedMark()
}

// Mirror the parent's document__comment-highlight--active styling so the marks
// of the open comment stand out inside the frame as well.
function applyFocusedMarkClass() {
    commentMarks.forEach(mark =>
        mark.classList.toggle("document__comment-highlight--active", Number(mark.dataset.commentId) === focusedCommentId)
    )
}

function reportFocusedMark() {
    if (focusedCommentId === null) return

    const marks = marksFor(focusedCommentId)
    const mark = marks[focusedMarkIndex] ?? marks[0]
    const visible = mark && isInFrameViewport(mark)

    postToParent({
        type: "docnotate:markRect",
        commentId: focusedCommentId,
        rect: visible ? rectOf(mark) : null
    })
}

function isInFrameViewport(element) {
    const { top, bottom } = element.getBoundingClientRect()
    return bottom > 0 && top < window.innerHeight
}

function scrollToTarget(message) {
    const hasCommentId = Number.isInteger(message.commentId)
    const hasBlockId = typeof message.blockId === "string"
    if (hasCommentId === hasBlockId) return

    if (hasCommentId) {
        marksFor(message.commentId)[0]?.scrollIntoView({ behavior: "smooth", block: "center" })
        return
    }

    const block = blockElements().find(element => blockIdOf(element) === message.blockId)
    block?.scrollIntoView({ behavior: "smooth", block: "start" })
}

// Headings drive the parent's TOC highlight; their positions are relative to the frame viewport.
function reportHeadings() {
    const entries = blockElements()
        .filter(block => HEADING_TAG_PATTERN.test(block.tagName))
        .map(block => ({ blockId: blockIdOf(block), top: block.getBoundingClientRect().top }))

    postToParent({ type: "docnotate:headings", entries })
}

function scheduleReport() {
    if (reportScheduled) return

    reportScheduled = true
    requestAnimationFrame(() => {
        reportScheduled = false
        if (activeMarks.length > 0) postToParent({ type: "docnotate:selectionMoved", rects: markRects() })
        reportFocusedMark()
        reportHeadings()
    })
}

function announceReady(attempt = 0) {
    if (readyAcked || attempt >= READY_MAX_ATTEMPTS) return

    postToParent({ type: "docnotate:ready" })
    setTimeout(() => announceReady(attempt + 1), READY_RETRY_MS)
}

document.addEventListener("mouseup", handleMouseUp)

document.addEventListener("keydown", event => {
    if (event.metaKey || event.ctrlKey) {
        postToParent({
            type: "docnotate:keydown",
            key: event.key,
            code: event.code,
            metaKey: event.metaKey,
            ctrlKey: event.ctrlKey,
            altKey: event.altKey,
            shiftKey: event.shiftKey
        })
    }
})

document.addEventListener("mousedown", () => {
    clearSelection()
    postToParent({ type: "docnotate:pointerdown" })
})

document.addEventListener("click", event => {
    if (!(event.target instanceof Element)) return

    const mark = event.target.closest(".document__comment-highlight")
    if (!mark) return

    const commentId = Number(mark.dataset.commentId)
    focusedCommentId = commentId
    focusedMarkIndex = marksFor(commentId).indexOf(mark)
    applyFocusedMarkClass()
    postToParent({ type: "docnotate:markClick", commentId, rect: rectOf(mark) })
})

window.addEventListener("scroll", scheduleReport, { passive: true })

window.addEventListener("message", event => {
    if (event.source !== window.parent) return

    switch (event.data?.type) {
        case "docnotate:ack":
            readyAcked = true
            reportHeadings()
            break
        case "docnotate:clearSelection":
            clearSelection()
            break
        case "docnotate:applyComments":
            applyComments(Array.isArray(event.data.comments) ? event.data.comments : [])
            break
        case "docnotate:focusComment":
            focusComment(Number.isInteger(event.data.commentId) ? event.data.commentId : null)
            break
        case "docnotate:scrollTo":
            scrollToTarget(event.data)
            break
    }
})

announceReady()
