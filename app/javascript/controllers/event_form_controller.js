import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startTime", "endTime", "allDayCheckbox", "recurrenceFields", "recurringCheckbox"]

  connect() {
    this.toggleAllDay()
    
    if (this.hasRecurringCheckboxTarget && this.hasRecurrenceFieldsTarget) {
      const isRecurring = this.recurringCheckboxTarget.checked
      const inputs = this.recurrenceFieldsTarget.querySelectorAll('input, select')
      
      if (!isRecurring) {
        this.recurrenceFieldsTarget.classList.add('hidden')
        inputs.forEach(input => input.disabled = true)
      }
    }
  }

  toggleAllDay() {
    const allDayCheckbox = this.element.querySelector('input[type="checkbox"][name*="all_day"]')
    
    if (!allDayCheckbox) return

    const isAllDay = allDayCheckbox.checked
    const startTimeField = this.element.querySelector('input[name*="starts_at"]')
    const endTimeField = this.element.querySelector('input[name*="ends_at"]')

    if (isAllDay) {
      if (startTimeField && startTimeField.parentElement) {
        const helperText = startTimeField.parentElement.querySelector('.all-day-helper')
        if (!helperText) {
          const helper = document.createElement('p')
          helper.className = 'text-xs text-neutral-500 mt-1 all-day-helper'
          helper.textContent = 'Times will be set to start/end of day'
          startTimeField.parentElement.appendChild(helper)
        }
      }
    } else {
      const helpers = this.element.querySelectorAll('.all-day-helper')
      helpers.forEach(helper => helper.remove())
    }
  }

  toggleRecurrence(event) {
    const isRecurring = event.target.checked
    
    if (this.hasRecurrenceFieldsTarget) {
      const inputs = this.recurrenceFieldsTarget.querySelectorAll('input, select')
      
      if (isRecurring) {
        this.recurrenceFieldsTarget.classList.remove('hidden')
        inputs.forEach(input => input.disabled = false)
      } else {
        this.recurrenceFieldsTarget.classList.add('hidden')
        inputs.forEach(input => input.disabled = true)
      }
    }
  }
}

