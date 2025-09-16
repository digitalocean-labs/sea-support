// app/javascript/controllers/demo_ticket_controller.js
// LEARNING NOTE: Stimulus Controller for Demo Ticket Generation
// Handles AI-powered demo ticket data generation and form population

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "generateButton",
    "loadingSpinner", 
    "errorMessage",
    "successMessage"
  ]

  // LEARNING NOTE: Stimulus connects when DOM loads
  connect() {
    console.log("🎪 Demo ticket controller connected")
  }

  // Generate demo ticket data using AI
  async generateDemo() {
    console.log("🎭 Generating demo ticket...")
    
    // Show loading state
    this.showLoading()
    this.hideMessages()
    
    try {
      // Call the backend API to generate demo ticket data
      const response = await fetch('/tickets/generate_demo_ticket', {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }
      
      const demoData = await response.json()
      console.log("🤖 Received demo data:", demoData)
      
      // Populate the form with generated data
      this.populateForm(demoData)
      this.showSuccess("✨ Demo ticket generated! Feel free to modify or generate another.")
      
    } catch (error) {
      console.error("❌ Demo generation failed:", error)
      this.showError(`Failed to generate demo ticket: ${error.message}`)
    } finally {
      this.hideLoading()
    }
  }

  // Populate form fields with demo data
  populateForm(data) {
    console.log("📝 Populating form with demo data...")
    
    // Main ticket fields
    this.setFieldValue('ticket[subject]', data.subject)
    this.setFieldValue('ticket[description]', data.description)
    this.setFieldValue('ticket[priority]', data.priority)
    this.setFieldValue('ticket[channel]', data.channel)
    this.setFieldValue('ticket[issue_category]', data.issue_category)
    this.setFieldValue('ticket[machine_model]', data.machine_model)
    this.setFieldValue('ticket[customer_mood]', data.customer_mood)
    
    // Customer information fields
    if (data.customer_info) {
      this.setFieldValue('ticket[customer_info_attributes][customer_name]', data.customer_info.customer_name)
      this.setFieldValue('ticket[customer_info_attributes][email]', data.customer_info.email)
      this.setFieldValue('ticket[customer_info_attributes][phone]', data.customer_info.phone)
      this.setFieldValue('ticket[customer_info_attributes][account_tier]', data.customer_info.account_tier)
      this.setFieldValue('ticket[customer_info_attributes][moodbrew_serial]', data.customer_info.moodbrew_serial)
      this.setFieldValue('ticket[customer_info_attributes][purchase_date]', data.customer_info.purchase_date)
      this.setFieldValue('ticket[customer_info_attributes][warranty_status]', data.customer_info.warranty_status)
    }
    
    // Trigger any change events for reactive components
    this.triggerFormEvents()
  }

  // Set field value with error handling
  setFieldValue(fieldName, value) {
    if (!value) return
    
    const field = document.querySelector(`[name="${fieldName}"]`)
    if (field) {
      field.value = value
      
      // Trigger change event for select fields and reactive components
      field.dispatchEvent(new Event('change', { bubbles: true }))
      
      // Add visual feedback for populated fields
      field.classList.add('demo-populated')
      setTimeout(() => field.classList.remove('demo-populated'), 2000)
    } else {
      console.warn(`Field not found: ${fieldName}`)
    }
  }

  // Trigger events for any reactive form components
  triggerFormEvents() {
    // Dispatch a custom event that other controllers can listen to
    this.element.dispatchEvent(new CustomEvent('demo:populated', {
      bubbles: true,
      detail: { message: 'Demo data populated' }
    }))
  }

  // Show loading state
  showLoading() {
    if (this.hasGenerateButtonTarget) {
      this.generateButtonTarget.disabled = true
      this.generateButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Generating...
      `
    }
    
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.remove('hidden')
    }
  }

  // Hide loading state
  hideLoading() {
    if (this.hasGenerateButtonTarget) {
      this.generateButtonTarget.disabled = false
      this.generateButtonTarget.innerHTML = `
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
        </svg>
        Generate Demo Ticket
      `
    }
    
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.add('hidden')
    }
  }

  // Show success message
  showSuccess(message) {
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.textContent = message
      this.successMessageTarget.classList.remove('hidden')
      
      // Auto-hide after 5 seconds
      setTimeout(() => {
        this.hideMessages()
      }, 5000)
    }
  }

  // Show error message
  showError(message) {
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.textContent = message
      this.errorMessageTarget.classList.remove('hidden')
    }
  }

  // Hide all messages
  hideMessages() {
    if (this.hasSuccessMessageTarget) {
      this.successMessageTarget.classList.add('hidden')
    }
    if (this.hasErrorMessageTarget) {
      this.errorMessageTarget.classList.add('hidden')
    }
  }

  // Get CSRF token for secure requests
  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : null
  }
}