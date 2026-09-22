import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.frame = requestAnimationFrame(() => {
      const header = document.querySelector(".agenda-sticky-header")
      const offset = (header?.getBoundingClientRect().height || 0) + 16
      window.scrollTo({
        top: Math.max(0, window.scrollY + this.element.getBoundingClientRect().top - offset),
        behavior: "instant"
      })
    })
  }

  disconnect() {
    cancelAnimationFrame(this.frame)
  }
}
