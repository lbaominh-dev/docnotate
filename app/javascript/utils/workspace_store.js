const STORAGE_KEY = "docnotate_workspaces"
const MAX_WORKSPACES = 20
const DEFAULT_NAME = "Untitled workspace"

function cleanName(name) {
  return typeof name === "string" && name.trim() ? name.trim() : null
}

function normalize(workspace) {
  if (!workspace || typeof workspace.token !== "string" || !workspace.token) return null

  return {
    token: workspace.token,
    name: cleanName(workspace.name) || DEFAULT_NAME,
    lastUsedAt: Number(workspace.lastUsedAt) || 0
  }
}

function sortByRecent(workspaces) {
  return [...workspaces].sort((a, b) => b.lastUsedAt - a.lastUsedAt).slice(0, MAX_WORKSPACES)
}

function persist(workspaces) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(sortByRecent(workspaces)))
  } catch (error) {
    console.warn("DocNotate: Unable to save workspaces", error)
  }
}

export function loadWorkspaces() {
  try {
    const parsed = JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]")
    if (!Array.isArray(parsed)) return []

    const byToken = new Map()
    parsed.map(normalize).filter(Boolean).forEach(workspace => {
      const existing = byToken.get(workspace.token)
      if (!existing || workspace.lastUsedAt > existing.lastUsedAt) {
        byToken.set(workspace.token, workspace)
      }
    })

    return sortByRecent([...byToken.values()])
  } catch {
    return []
  }
}

export function rememberWorkspace({ token, name }) {
  if (!token) return loadWorkspaces()

  const workspaces = loadWorkspaces()
  const existing = workspaces.find(workspace => workspace.token === token)

  if (existing) {
    existing.name = cleanName(name) || existing.name
    existing.lastUsedAt = Date.now()
  } else {
    workspaces.push({
      token,
      name: cleanName(name) || DEFAULT_NAME,
      lastUsedAt: Date.now()
    })
  }

  const sorted = sortByRecent(workspaces)
  persist(sorted)
  return sorted
}

export function forgetWorkspace(token) {
  const remaining = loadWorkspaces().filter(workspace => workspace.token !== token)
  persist(remaining)
  return remaining
}

export function maskedToken(token) {
  if (!token) return ""
  return `docn_…${token.slice(-4)}`
}
