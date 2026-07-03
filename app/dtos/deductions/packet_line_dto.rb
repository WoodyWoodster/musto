module Deductions
  PacketLineDto = Data.define(:deduction_id, :payroll_deduction_id, :employee_id, :employee_name, :title, :deduction_type, :amount_cents, :priority, :pre_tax, :agency_name, :case_number, :status) do
    def self.from_hash(payload)
      new(
        deduction_id: payload.fetch("deduction_id", nil),
        payroll_deduction_id: payload.fetch("payroll_deduction_id", nil),
        employee_id: payload.fetch("employee_id", nil),
        employee_name: payload.fetch("employee_name", "Employee pending"),
        title: payload.fetch("title", "Deduction"),
        deduction_type: payload.fetch("deduction_type", "other"),
        amount_cents: payload.fetch("amount_cents", 0),
        priority: payload.fetch("priority", 50),
        pre_tax: payload.fetch("pre_tax", false),
        agency_name: payload.fetch("agency_name", nil),
        case_number: payload.fetch("case_number", nil),
        status: payload.fetch("status", "withheld")
      )
    end
  end
end
