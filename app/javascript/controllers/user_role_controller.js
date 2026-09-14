import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["role", "details"]

  connect() {
    this.toggle()
  }

  toggle() {
    const isCustomer = this.roleTarget.value === "customer"
    this.detailsTarget.hidden = !isCustomer
    this.detailsTarget.disabled = !isCustomer
  }
}
