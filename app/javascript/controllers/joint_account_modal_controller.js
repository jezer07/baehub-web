import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "backdrop"]

  connect() {
    document.body.style.overflow = "hidden"
  }

  disconnect() {
    document.body.style.overflow = ""
  }

  close(event) {
    if (event && event.target !== this.backdropTarget && !this.modalTarget.contains(event.target)) {
      return
    }

    this.element.remove()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}

