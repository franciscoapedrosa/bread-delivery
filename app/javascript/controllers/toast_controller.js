import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeout = window.setTimeout(() => this.close(), 5000)
  }

  disconnect() {
    window.clearTimeout(this.timeout)
    window.clearTimeout(this.removeTimeout)
  }

  close() {
    window.clearTimeout(this.timeout)
    this.element.classList.add("is-closing")
    this.removeTimeout = window.setTimeout(() => this.element.remove(), 200)
  }
}
