import { Controller } from "@hotwired/stimulus"
import React from "react"
import { createRoot } from "react-dom/client"
import {
  EmployeeViewWidget,
  EmployerBenefitsWidget,
  EmployerBillingWidget,
  VitableConnectProvider
} from "@vitable-inc/drops/react"

const WIDGETS = {
  "employee-dashboard": EmployeeViewWidget,
  "employer-benefits": EmployerBenefitsWidget,
  "employer-billing": EmployerBillingWidget
}

export default class extends Controller {
  static targets = ["container", "status"]
  static values = {
    contextKey: String,
    height: { type: String, default: "760px" },
    launchToken: String,
    tokenUrl: String,
    widget: String,
    widgetUrl: String
  }

  disconnect() {
    this.root?.unmount()
    this.root = null
  }

  launch() {
    if (!this.hasContainerTarget) return

    this.containerTarget.classList.remove("hidden")
    this.setStatus("Loading")

    if (!this.root) this.root = createRoot(this.containerTarget)

    this.root.render(
      React.createElement(
        VitableConnectProvider,
        {
          baseUrl: this.widgetUrlValue,
          contextKey: this.contextKeyValue,
          fetchToken: () => this.fetchToken(),
          onError: (_code, message) => this.setStatus(message || "Error")
        },
        React.createElement(this.widgetComponent(), {
          className: "rounded-md border border-slate-200 bg-white shadow-sm",
          height: this.heightValue,
          onAppointmentScheduled: () => this.setStatus("Appointment scheduled"),
          onAuthError: (_code, message) => this.setStatus(message || "Authentication failed"),
          onEmployeeViewReady: () => this.setStatus("Ready"),
          onEmployerBenefitsReady: () => this.setStatus("Ready"),
          onEmployerBillingReady: () => this.setStatus("Ready"),
          onEnrollmentComplete: () => this.setStatus("Enrollment complete"),
          onError: (_code, message) => this.setStatus(message || "Error"),
          onQleSubmitted: () => this.setStatus("Life event submitted"),
          onReady: () => this.setStatus("Ready"),
          onTokenExpired: () => this.setStatus("Refreshing")
        })
      )
    )
  }

  async fetchToken() {
    const response = await fetch(this.tokenUrlValue, {
      body: JSON.stringify({ requested_by: "vitable_drops_widget" }),
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-Musto-Widget-Launch": this.launchTokenValue,
        "X-CSRF-Token": this.csrfToken()
      },
      method: "POST"
    })

    const data = await response.json()
    if (!response.ok) throw new Error(data.errors?.join(", ") || `Token fetch failed: ${response.status}`)

    return {
      token: data.access_token,
      expiresIn: Number(data.expires_in || data.expiresIn)
    }
  }

  widgetComponent() {
    const component = WIDGETS[this.widgetValue]
    if (!component) throw new Error(`Unsupported Vitable widget: ${this.widgetValue}`)

    return component
  }

  csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  setStatus(message) {
    if (this.hasStatusTarget) this.statusTarget.textContent = message
  }
}
