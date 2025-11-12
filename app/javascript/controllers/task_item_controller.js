import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cancelButton"]

  connect() {
    this._onKeydown = this.handleEscape.bind(this)
    document.addEventListener("keydown", this._onKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this._onKeydown)
    this._onKeydown = null
  }

  handleEscape(event) {
    if (event.key === "Escape") {
      // Only handle escape if this form is focused or a descendant is focused
      if (this.element.contains(document.activeElement)) {
        event.preventDefault()
        if (this.hasCancelButtonTarget) {
          this.cancelButtonTarget.click()
        }
      }
    }
  }
}
