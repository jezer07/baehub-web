import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["direction", "amountInput"]

  connect() {
    this.validateForm()
  }

  validateForm() {
    const direction = this.directionTarget.value
    const amount = this.amountInputTarget.value

    const isValid = direction && amount && parseFloat(amount) > 0

    const submitButton = this.element.querySelector('input[type="submit"]')
    if (submitButton) {
      submitButton.disabled = !isValid
    }
  }

  handleDirectionChange() {
    this.validateForm()
  }

  handleAmountChange() {
    this.validateForm()
  }
}

