import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "backdrop"]

  toggle() {
    const isHidden = this.menuTarget.classList.contains("hidden")
    
    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    this.menuTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    
    setTimeout(() => {
      this.menuTarget.classList.remove("translate-x-full")
      this.menuTarget.classList.add("translate-x-0")
      this.backdropTarget.classList.remove("opacity-0")
      this.backdropTarget.classList.add("opacity-100")
    }, 10)
  }

  close() {
    this.menuTarget.classList.remove("translate-x-0")
    this.menuTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    
    setTimeout(() => {
      this.menuTarget.classList.add("hidden")
      this.backdropTarget.classList.add("hidden")
    }, 300)
  }
}

