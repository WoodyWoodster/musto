module Compensation
  ChangePacketLineDto = Data.define(
    :change_id,
    :employee_id,
    :employee_name,
    :department_name,
    :change_type,
    :reason,
    :effective_on,
    :current_compensation_cents,
    :proposed_compensation_cents,
    :delta_cents,
    :base_pay_change,
    :payroll_run_id,
    :status
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        change_id: attributes.fetch("change_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        department_name: attributes.fetch("department_name"),
        change_type: attributes.fetch("change_type"),
        reason: attributes.fetch("reason"),
        effective_on: Date.iso8601(attributes.fetch("effective_on")),
        current_compensation_cents: attributes.fetch("current_compensation_cents"),
        proposed_compensation_cents: attributes.fetch("proposed_compensation_cents"),
        delta_cents: attributes.fetch("delta_cents"),
        base_pay_change: attributes.fetch("base_pay_change"),
        payroll_run_id: attributes.fetch("payroll_run_id", nil),
        status: attributes.fetch("status")
      )
    end
  end
end
