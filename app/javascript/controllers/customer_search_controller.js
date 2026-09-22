import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "customer", "empty", "list", "group"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.normalize(this.inputTarget.value.trim())
    let matches = 0
    this.customerTargets.forEach((customer) => {
      const visible = this.normalize(customer.dataset.customerName).includes(query)
      customer.hidden = !visible
      if (visible) matches += 1
    })
    this.emptyTarget.hidden = !query || matches > 0
    this.groupTargets.forEach((group) => {
      group.hidden = Boolean(query) && !Array.from(group.querySelectorAll('[data-customer-search-target="customer"]')).some((customer) => !customer.hidden)
    })
    if (this.hasListTarget) this.listTarget.hidden = Boolean(query) && matches === 0
  }

  normalize(value) {
    return value.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLocaleLowerCase("pt-PT")
  }
}
