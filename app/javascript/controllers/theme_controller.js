import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.boundSystemChange = this.onSystemChange.bind(this)
    this.boundStorageChange = this.onStorageChange.bind(this)

    this.mediaQuery.addEventListener("change", this.boundSystemChange)
    window.addEventListener("storage", this.boundStorageChange)

    const preference = localStorage.getItem("docnotate-theme") ||
                       document.documentElement.dataset.themePreference ||
                       "system"

    this.applyTheme(preference, false)
  }

  disconnect() {
    this.mediaQuery.removeEventListener("change", this.boundSystemChange)
    window.removeEventListener("storage", this.boundStorageChange)
  }

  setTheme(event) {
    const preference = event.currentTarget.dataset.themeValue
    if (!preference) return

    this.applyTheme(preference, true)
  }

  applyTheme(preference, persist = false) {
    const isDark = preference === "dark" || (preference === "system" && this.mediaQuery.matches)
    const effectiveTheme = isDark ? "dark" : "light"

    document.documentElement.setAttribute("data-theme", effectiveTheme)
    document.documentElement.setAttribute("data-theme-preference", preference)

    this.updateUI(preference)

    if (persist) {
      localStorage.setItem("docnotate-theme", preference)
      document.cookie = `theme=${preference}; path=/; max-age=31536000; SameSite=Lax`

      const token = document.querySelector('meta[name="csrf-token"]')?.content
      fetch("/settings/theme", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          ...(token ? { "X-CSRF-Token": token } : {})
        },
        body: JSON.stringify({ theme: preference })
      }).catch(() => {})
    }
  }

  updateUI(preference) {
    const buttons = this.hasButtonTarget
      ? this.buttonTargets
      : document.querySelectorAll("[data-theme-value]")

    buttons.forEach((btn) => {
      const match = btn.dataset.themeValue === preference
      btn.classList.toggle("home-settings__theme-btn--active", match)
      btn.setAttribute("aria-pressed", match ? "true" : "false")
    })
  }

  onSystemChange() {
    const preference = document.documentElement.getAttribute("data-theme-preference") || "system"
    if (preference === "system") {
      this.applyTheme("system", false)
    }
  }

  onStorageChange(event) {
    if (event.key === "docnotate-theme" && event.newValue) {
      this.applyTheme(event.newValue, false)
    }
  }
}
