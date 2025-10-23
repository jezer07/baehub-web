import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "backdrop"]

  toggle() {
    if (this.modalTarget.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    
    requestAnimationFrame(() => {
      this.modalTarget.classList.remove("translate-x-full")
      this.modalTarget.classList.add("translate-x-0")
      this.backdropTarget.classList.remove("opacity-0")
      this.backdropTarget.classList.add("opacity-100")
      this.backdropTarget.classList.remove("pointer-events-none")
    })
  }

  close() {
    this.modalTarget.classList.remove("translate-x-0")
    this.modalTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    this.backdropTarget.classList.add("pointer-events-none")
    
    setTimeout(() => {
      this.modalTarget.classList.add("hidden")
      this.backdropTarget.classList.add("hidden")
    }, 300)
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  connect() {
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.boundCloseOnEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }
}

