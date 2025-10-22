import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.timeoutId = setTimeout(() => {
      this.dismiss()
    }, 5000)
  }

  disconnect() {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  dismiss() {
    this.element.classList.add("transition-opacity", "duration-300", "opacity-0")
    
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}

