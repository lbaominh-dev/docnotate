// Robust clipboard copy with fallback for non-secure HTTP contexts (where navigator.clipboard is undefined)
export async function copyToClipboard(text) {
  if (typeof text !== "string") {
    text = String(text ?? "")
  }

  // 1. Modern Async Clipboard API (Secure contexts: HTTPS / localhost)
  if (navigator?.clipboard?.writeText && window.isSecureContext) {
    try {
      await navigator.clipboard.writeText(text)
      return true
    } catch (e) {
      // If permission denied or rejected, fall through to execCommand
    }
  }

  // 2. Fallback: Hidden textarea with document.execCommand('copy')
  try {
    const textArea = document.createElement("textarea")
    textArea.value = text
    textArea.style.position = "fixed"
    textArea.style.top = "0"
    textArea.style.left = "0"
    textArea.style.width = "2em"
    textArea.style.height = "2em"
    textArea.style.padding = "0"
    textArea.style.border = "none"
    textArea.style.outline = "none"
    textArea.style.boxShadow = "none"
    textArea.style.background = "transparent"
    textArea.style.opacity = "0"

    document.body.appendChild(textArea)
    textArea.focus()
    textArea.select()

    const successful = document.execCommand("copy")
    document.body.removeChild(textArea)
    if (successful) return true
  } catch (err) {
    // If execCommand failed, proceed to prompt fallback
  }

  // 3. Last-resort fallback for insecure context where clipboard access is restricted:
  // Show prompt dialog so user can manually press Ctrl+C / Cmd+C
  if (typeof window !== "undefined" && window.prompt) {
    window.prompt("Copy to clipboard (press ⌘C / Ctrl+C, then Enter):", text)
    return true
  }

  return false
}
