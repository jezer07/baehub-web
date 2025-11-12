import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "splitFields",
    "equalFields",
    "percentageFields",
    "customAmountsFields",
    "amountInput",
    "amountCentsInput",
    "equalAmount",
    "percentageValidation",
    "customAmountsValidation",
    "submitButton",
    "percentageAmount",
    "customAmountPrefix"
  ]

  static values = {
    totalAmount: Number,
    currencySymbols: Object,
    defaultCurrency: String
  }

  connect() {
    if (!this.hasCurrencySymbolsValue) {
      this.currencySymbolsValue = {
        "USD": "$",
        "EUR": "€",
        "GBP": "£",
        "JPY": "¥",
        "CAD": "C$",
        "AUD": "A$",
        "PHP": "₱"
      }
    }

    if (!this.hasDefaultCurrencyValue) {
      this.defaultCurrencyValue = "USD"
    }

    this.updateSplitFields()
    this.convertAmountToCents()
    this.updateCurrencySymbols()
  }

  updateSplitFields(event) {
    const selectedStrategy = event?.target?.value || this.getSelectedStrategy()

    if (this.hasEqualFieldsTarget) {
      this.equalFieldsTarget.classList.add("hidden")
    }
    if (this.hasPercentageFieldsTarget) {
      this.percentageFieldsTarget.classList.add("hidden")
    }
    if (this.hasCustomAmountsFieldsTarget) {
      this.customAmountsFieldsTarget.classList.add("hidden")
    }

    if (selectedStrategy === "equal" && this.hasEqualFieldsTarget) {
      this.equalFieldsTarget.classList.remove("hidden")
      this.calculateEqualSplit()
    } else if (selectedStrategy === "percentage" && this.hasPercentageFieldsTarget) {
      this.percentageFieldsTarget.classList.remove("hidden")
    } else if (selectedStrategy === "custom_amounts" && this.hasCustomAmountsFieldsTarget) {
      this.customAmountsFieldsTarget.classList.remove("hidden")
    }
  }

  getSelectedStrategy() {
    const checkedRadio = this.element.querySelector('input[name="expense[split_strategy]"]:checked')
    return checkedRadio ? checkedRadio.value : "equal"
  }

  convertAmountToCents() {
    if (!this.hasAmountInputTarget || !this.hasAmountCentsInputTarget) return

    const amountValue = parseFloat(this.amountInputTarget.value) || 0
    const cents = Math.round(amountValue * 100)
    
    this.amountCentsInputTarget.value = cents
    this.totalAmountValue = cents

    if (this.getSelectedStrategy() === "equal") {
      this.calculateEqualSplit()
    }
  }

  calculateEqualSplit() {
    if (!this.hasEqualAmountTarget) return

    const totalCents = this.totalAmountValue || 0
    const numberOfUsers = 2
    const baseAmount = Math.floor(totalCents / numberOfUsers)
    const remainder = totalCents % numberOfUsers
    
    if (remainder > 0) {
      const amount1 = baseAmount + 1
      const amount2 = baseAmount
      this.equalAmountTarget.textContent = `${this.formatCurrency(amount1)} and ${this.formatCurrency(amount2)}`
    } else {
      this.equalAmountTarget.textContent = this.formatCurrency(baseAmount)
    }
  }

  validatePercentages(event) {
    const percentageInputs = Array.from(this.percentageFieldsTarget.querySelectorAll('input[type="number"]'))

    if (event) {
      this.adjustComplementaryPercentage(event.target, percentageInputs)
    }

    let total = 0

    percentageInputs.forEach(input => {
      const value = parseFloat(input.value) || 0
      total += value
    })

    const isValid = Math.abs(total - 100) < 0.01 || total === 0

    if (!isValid) {
      this.showValidationError(this.percentageValidationTarget, `Percentages must add up to 100% (currently ${total.toFixed(1)}%)`)
      this.disableSubmit()
    } else {
      this.hideValidationError(this.percentageValidationTarget)
      this.enableSubmit()
    }

    this.percentageAmountTargets.forEach((amountDisplay, index) => {
      const input = percentageInputs[index]
      if (input) {
        const percentage = parseFloat(input.value) || 0
        const amount = Math.round((this.totalAmountValue * percentage) / 100)
        amountDisplay.textContent = this.formatCurrency(amount)
      }
    })
  }

  validateCustomAmounts(event) {
    const amountInputs = Array.from(this.customAmountsFieldsTarget.querySelectorAll('input[type="number"]'))

    if (event) {
      this.adjustComplementaryCustomAmount(event.target, amountInputs)
    }

    let totalCents = 0

    amountInputs.forEach(input => {
      const value = parseFloat(input.value) || 0
      totalCents += Math.round(value * 100)
    })

    const expectedTotal = this.totalAmountValue || 0
    const isValid = totalCents === expectedTotal || totalCents === 0

    if (!isValid) {
      this.showValidationError(
        this.customAmountsValidationTarget,
        `Amounts must add up to ${this.formatCurrency(expectedTotal)} (currently ${this.formatCurrency(totalCents)})`
      )
      this.disableSubmit()
    } else {
      this.hideValidationError(this.customAmountsValidationTarget)
      this.enableSubmit()
    }
  }

  formatCurrency(cents) {
    const amount = cents / 100
    const currency = this.getSelectedCurrency()
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: currency
    }).format(amount)
  }

  getSelectedCurrency() {
    return this.defaultCurrencyValue || "USD"
  }

  updateCurrencySymbols() {
    const currency = this.getSelectedCurrency()
    const symbols = this.currencySymbolsValue || {}
    const fallbackSymbol = symbols[this.defaultCurrencyValue] || "$"
    const symbol = symbols[currency] || fallbackSymbol || "$"

    this.customAmountPrefixTargets.forEach((prefix) => {
      prefix.textContent = symbol
    })
  }

  disableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  enableSubmit() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
  }

  showValidationError(target, message) {
    if (!target) return
    target.classList.remove("hidden")
    const paragraph = target.querySelector("p")
    if (paragraph) {
      paragraph.textContent = message
    }
  }

  hideValidationError(target) {
    if (!target) return
    target.classList.add("hidden")
  }

  adjustComplementaryPercentage(changedInput, inputs) {
    if (!changedInput || inputs.length !== 2) return
    if (!inputs.includes(changedInput)) return

    const otherInput = inputs.find(input => input !== changedInput)
    const rawValue = parseFloat(changedInput.value)

    if (Number.isNaN(rawValue)) return

    const boundedValue = Math.min(Math.max(rawValue, 0), 100)
    const complement = Math.max(0, 100 - boundedValue)

    changedInput.value = this.roundToTwoDecimals(boundedValue)
    otherInput.value = this.roundToTwoDecimals(complement)
  }

  adjustComplementaryCustomAmount(changedInput, inputs) {
    if (!changedInput || inputs.length !== 2) return
    if (!inputs.includes(changedInput)) return

    const totalCents = this.totalAmountValue || 0
    if (totalCents <= 0) return

    const otherInput = inputs.find(input => input !== changedInput)
    const rawValue = parseFloat(changedInput.value)
    if (Number.isNaN(rawValue)) return

    const cents = Math.round(rawValue * 100)
    const boundedCents = Math.min(Math.max(cents, 0), totalCents)
    const complementCents = Math.max(0, totalCents - boundedCents)

    changedInput.value = this.roundToTwoDecimals(boundedCents / 100)
    otherInput.value = this.roundToTwoDecimals(complementCents / 100)
  }

  roundToTwoDecimals(value) {
    return (Math.round(value * 100) / 100).toString()
  }
}
