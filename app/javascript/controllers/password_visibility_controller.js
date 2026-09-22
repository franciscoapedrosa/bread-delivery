import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button", "slash"]

  connect() {
    this.hide()
  }

  toggle() {
    this.setVisible(this.inputTarget.type === "password")
  }

  hide() {
    this.setVisible(false)
  }

  setVisible(visible) {
    this.inputTarget.type = visible ? "text" : "password"
    this.buttonTarget.setAttribute("aria-pressed", String(visible))
    this.buttonTarget.setAttribute("aria-label", visible ? "Ocultar palavra-passe" : "Mostrar palavra-passe")
    this.slashTarget.toggleAttribute("hidden", !visible)
  }
}
