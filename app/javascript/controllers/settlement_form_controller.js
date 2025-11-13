import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "totalAmount", "submitButton"]

  connect() {
    this.updateTotal()
  }

  toggleEntry(event) {
    this.updateTotal()
  }

  updateTotal() {
    const selectedCheckboxes = this.checkboxTargets.filter(cb => cb.checked)
    const total = selectedCheckboxes.reduce((sum, cb) => {
      return sum + parseFloat(cb.dataset.amount || 0)
    }, 0)

    if (this.hasTotalAmountTarget) {
      this.totalAmountTarget.value = Math.round(total * 100)
      this.totalAmountTarget.dataset.displayValue = total.toFixed(2)
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = selectedCheckboxes.length === 0
    }
  }

  selectAll(event) {
    const shouldCheck = event.target.checked
    this.checkboxTargets.forEach(cb => {
      cb.checked = shouldCheck
    })
    this.updateTotal()
  }
}

