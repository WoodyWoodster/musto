module Garnishments
  PacketLineDto = Data.define(
    :deduction_id,
    :payroll_deduction_id,
    :employee_id,
    :employee_name,
    :employee_title,
    :department_name,
    :title,
    :deduction_type,
    :agency_name,
    :case_number,
    :priority,
    :gross_cents,
    :disposable_earnings_cents,
    :amount_cents,
    :remittance_method,
    :service_state,
    :pay_date,
    :due_on,
    :status
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        deduction_id: attributes.fetch("deduction_id"),
        payroll_deduction_id: attributes.fetch("payroll_deduction_id", nil),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        employee_title: attributes.fetch("employee_title", nil),
        department_name: attributes.fetch("department_name", nil),
        title: attributes.fetch("title"),
        deduction_type: attributes.fetch("deduction_type"),
        agency_name: attributes.fetch("agency_name"),
        case_number: attributes.fetch("case_number"),
        priority: attributes.fetch("priority", 50),
        gross_cents: attributes.fetch("gross_cents", 0),
        disposable_earnings_cents: attributes.fetch("disposable_earnings_cents", 0),
        amount_cents: attributes.fetch("amount_cents", 0),
        remittance_method: attributes.fetch("remittance_method", "agency_ach"),
        service_state: attributes.fetch("service_state", "Federal"),
        pay_date: Date.iso8601(attributes.fetch("pay_date")),
        due_on: Date.iso8601(attributes.fetch("due_on")),
        status: attributes.fetch("status", "withheld")
      )
    end
  end
end
