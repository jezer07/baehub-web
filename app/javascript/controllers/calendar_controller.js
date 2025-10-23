import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["calendar", "calendarView", "listView"]
  static values = {
    currentDate: String,
    viewMode: String
  }

  connect() {
    const urlParams = new URLSearchParams(window.location.search)
    const viewParam = urlParams.get('view')
    
    if (viewParam && ['month', 'week', 'day', 'list'].includes(viewParam)) {
      this.viewModeValue = viewParam
    } else {
      this.viewModeValue = this.viewModeValue || "list"
    }
    
    this.currentDateValue = this.currentDateValue || new Date().toISOString().split('T')[0]
    
    const buttons = this.element.querySelectorAll('button[data-view]')
    buttons.forEach((btn) => {
      if (btn.dataset.view === this.viewModeValue) {
        btn.classList.remove('bg-neutral-100', 'text-neutral-700', 'hover:bg-neutral-200')
        btn.classList.add('bg-primary-600', 'text-white')
      } else {
        btn.classList.remove('bg-primary-600', 'text-white')
        btn.classList.add('bg-neutral-100', 'text-neutral-700', 'hover:bg-neutral-200')
      }
    })
    
    if (this.viewModeValue === "list") {
      this.showListView()
    } else {
      this.showCalendarView()
    }
  }

  switchView(event) {
    const viewMode = event.currentTarget.dataset.view
    this.viewModeValue = viewMode

    const buttons = event.currentTarget.parentElement.querySelectorAll('button')
    buttons.forEach(btn => {
      if (btn.dataset.view === viewMode) {
        btn.classList.remove('bg-neutral-100', 'text-neutral-700', 'hover:bg-neutral-200')
        btn.classList.add('bg-primary-600', 'text-white')
      } else {
        btn.classList.remove('bg-primary-600', 'text-white')
        btn.classList.add('bg-neutral-100', 'text-neutral-700', 'hover:bg-neutral-200')
      }
    })

    if (viewMode === "list") {
      this.showListView()
    } else {
      this.showCalendarView()
    }
  }

  showListView() {
    if (this.hasListViewTarget) {
      this.listViewTarget.classList.remove("hidden")
    }
    if (this.hasCalendarViewTarget) {
      this.calendarViewTarget.classList.add("hidden")
    }
  }

  showCalendarView() {
    if (this.hasListViewTarget) {
      this.listViewTarget.classList.add("hidden")
    }
    if (this.hasCalendarViewTarget) {
      this.calendarViewTarget.classList.remove("hidden")
    }
  }

  previousPeriod() {
    const currentDate = new Date(this.currentDateValue)
    
    if (this.viewModeValue === "month") {
      currentDate.setMonth(currentDate.getMonth() - 1)
    } else if (this.viewModeValue === "week") {
      currentDate.setDate(currentDate.getDate() - 7)
    } else if (this.viewModeValue === "day") {
      currentDate.setDate(currentDate.getDate() - 1)
    }
    
    this.currentDateValue = currentDate.toISOString().split('T')[0]
    this.navigateToDate()
  }

  nextPeriod() {
    const currentDate = new Date(this.currentDateValue)
    
    if (this.viewModeValue === "month") {
      currentDate.setMonth(currentDate.getMonth() + 1)
    } else if (this.viewModeValue === "week") {
      currentDate.setDate(currentDate.getDate() + 7)
    } else if (this.viewModeValue === "day") {
      currentDate.setDate(currentDate.getDate() + 1)
    }
    
    this.currentDateValue = currentDate.toISOString().split('T')[0]
    this.navigateToDate()
  }

  goToToday() {
    this.currentDateValue = new Date().toISOString().split('T')[0]
    this.navigateToDate()
  }

  navigateToDate() {
    const url = new URL(window.location.href)
    url.searchParams.set('date', this.currentDateValue)
    url.searchParams.set('view', this.viewModeValue)
    window.location.href = url.toString()
  }
}

