import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["event", "resourceId", "resourceType"]

  connect() {
    this.sync()
  }

  sync() {
    const option = this.eventTarget.selectedOptions[0]
    if (!option) return

    if (this.hasResourceTypeTarget && option.dataset.resourceType) {
      this.resourceTypeTarget.value = option.dataset.resourceType
    }

    if (this.hasResourceIdTarget) {
      this.resourceIdTarget.value = option.dataset.resourceId || ""
    }
  }
}
