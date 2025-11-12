import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "startTime",
    "endTime",
    "startDateOnly",
    "endDateOnly",
    "startTimeWrapper",
    "endTimeWrapper",
    "startDateWrapper",
    "endDateWrapper",
    "allDayCheckbox",
    "recurrenceFields",
    "recurringCheckbox"
  ]

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
    const isAllDay = this.hasAllDayCheckboxTarget
      ? this.allDayCheckboxTarget.checked
      : this.element.querySelector('input[type="checkbox"][name*="all_day"]')?.checked

    if (isAllDay) {
      this.showDateOnlyFields()
    } else {
      this.showDateTimeFields()
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

  showDateOnlyFields() {
    this.storePreviousValue(this.startTimeTarget)
    this.storePreviousValue(this.endTimeTarget)

    this.toggleWrapper(this.startTimeWrapperTarget, false)
    this.toggleWrapper(this.endTimeWrapperTarget, false)
    this.toggleWrapper(this.startDateWrapperTarget, true)
    this.toggleWrapper(this.endDateWrapperTarget, true)

    this.disableField(this.startTimeTarget, true)
    this.disableField(this.endTimeTarget, true)
    this.disableField(this.startDateOnlyTarget, false)
    this.disableField(this.endDateOnlyTarget, false)

    this.syncDateValue(this.startTimeTarget, this.startDateOnlyTarget)
    this.syncDateValue(this.endTimeTarget, this.endDateOnlyTarget)
  }

  showDateTimeFields() {
    this.toggleWrapper(this.startTimeWrapperTarget, true)
    this.toggleWrapper(this.endTimeWrapperTarget, true)
    this.toggleWrapper(this.startDateWrapperTarget, false)
    this.toggleWrapper(this.endDateWrapperTarget, false)

    this.disableField(this.startTimeTarget, false)
    this.disableField(this.endTimeTarget, false)
    this.disableField(this.startDateOnlyTarget, true)
    this.disableField(this.endDateOnlyTarget, true)

    this.restoreDateTimeValue(this.startTimeTarget, this.startDateOnlyTarget)
    this.restoreDateTimeValue(this.endTimeTarget, this.endDateOnlyTarget)
  }

  toggleWrapper(element, shouldShow) {
    if (!element) return
    element.classList.toggle('hidden', !shouldShow)
  }

  disableField(field, shouldDisable) {
    if (!field) return
    field.disabled = shouldDisable
  }

  syncDateValue(datetimeField, dateField) {
    if (!datetimeField || !dateField || dateField.value) return
    const value = datetimeField.value

    if (!value) return

    const [datePart] = value.split('T')
    if (datePart) {
      dateField.value = datePart
    }
  }

  restoreDateTimeValue(datetimeField, dateField) {
    if (!datetimeField || !dateField) return

    if (datetimeField.dataset.previousValue) {
      datetimeField.value = datetimeField.dataset.previousValue
      datetimeField.dataset.previousValue = ""
      return
    }

    if (!datetimeField.value && dateField.value) {
      datetimeField.value = `${dateField.value}T00:00`
    }
  }

  storePreviousValue(field) {
    if (!field) return
    field.dataset.previousValue = field.value
  }
}
