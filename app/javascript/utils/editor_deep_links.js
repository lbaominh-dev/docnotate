// Helper functions for Editor Deep Linking (Cloud & Local Mode)

export const SUPPORTED_EDITORS = [
  { id: "vscode", name: "Visual Studio Code", scheme: "vscode://file" },
  { id: "cursor", name: "Cursor", scheme: "cursor://file" },
  { id: "windsurf", name: "Windsurf", scheme: "windsurf://file" },
  { id: "idea", name: "JetBrains (IDEA, RubyMine, WebStorm)", scheme: "idea://open" },
  { id: "sublime", name: "Sublime Text", scheme: "subl://open" },
  { id: "custom", name: "Custom URL Scheme", scheme: "custom" }
]

export const STORAGE_KEYS = {
  SCHEME: "docnotate:editor_scheme",
  WORKSPACE: "docnotate:local_workspace_path",
  CUSTOM: "docnotate:custom_scheme_template"
}

export function getStoredEditorSettings() {
  try {
    return {
      scheme: localStorage.getItem(STORAGE_KEYS.SCHEME) || "vscode",
      workspacePath: localStorage.getItem(STORAGE_KEYS.WORKSPACE) || "",
      customTemplate: localStorage.getItem(STORAGE_KEYS.CUSTOM) || ""
    }
  } catch {
    return { scheme: "vscode", workspacePath: "", customTemplate: "" }
  }
}

export function saveStoredEditorSettings({ scheme, workspacePath, customTemplate }) {
  try {
    if (scheme !== undefined) localStorage.setItem(STORAGE_KEYS.SCHEME, scheme)
    if (workspacePath !== undefined) localStorage.setItem(STORAGE_KEYS.WORKSPACE, workspacePath.trim())
    if (customTemplate !== undefined) localStorage.setItem(STORAGE_KEYS.CUSTOM, customTemplate.trim())
  } catch (e) {
    console.warn("DocNotate: Unable to save editor settings to localStorage", e)
  }
}

export function resolveLocalFilePath(workspacePath, filePath) {
  if (!filePath) return ""
  let cleanFile = filePath.trim()

  if (workspacePath && workspacePath.trim()) {
    let cleanWorkspace = workspacePath.trim().replace(/[\\/]+$/, "")

    // If filePath already starts with workspacePath, return it directly
    if (cleanFile.startsWith(cleanWorkspace)) {
      return cleanFile
    }

    // Strip common server/container root prefixes if present
    cleanFile = cleanFile.replace(/^(\/app\/|\/workspace\/|\/var\/www\/)/, "")

    // Strip leading slashes to join with workspace
    cleanFile = cleanFile.replace(/^[\\/]+/, "")

    const separator = cleanWorkspace.includes("\\") ? "\\" : "/"
    return `${cleanWorkspace}${separator}${cleanFile.split("/").join(separator)}`
  }

  return cleanFile
}

export function buildEditorUrl(editor, absolutePath, customTemplate = "") {
  if (!absolutePath) return ""

  const normalizedPath = absolutePath.split("\\").join("/")
  const leadingSlashPath = normalizedPath.startsWith("/") ? normalizedPath : `/${normalizedPath}`

  switch (editor) {
    case "vscode":
      return `vscode://file${leadingSlashPath}`
    case "cursor":
      return `cursor://file${leadingSlashPath}`
    case "windsurf":
      return `windsurf://file${leadingSlashPath}`
    case "sublime":
      return `subl://open?url=file://${encodeURI(leadingSlashPath)}`
    case "idea":
      return `idea://open?file=${encodeURI(normalizedPath)}`
    case "custom":
      if (customTemplate) {
        return customTemplate
          .replace("{path}", normalizedPath)
          .replace("{file}", leadingSlashPath)
      }
      return `vscode://file${leadingSlashPath}`
    default:
      return `vscode://file${leadingSlashPath}`
  }
}

export function triggerDeepLink(url) {
  const link = document.createElement("a")
  link.href = url
  link.style.display = "none"
  document.body.appendChild(link)
  link.click()
  setTimeout(() => {
    link.remove()
  }, 100)
}
