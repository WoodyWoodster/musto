module Lifecycle
  SyncLineDto = Data.define(
    :event_id,
    :employee_id,
    :employee_name,
    :remote_employee_id,
    :event_type,
    :effective_on,
    :summary,
    :payroll_impact,
    :benefits_impact,
    :compliance_impact
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        event_id: attributes.fetch("event_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        remote_employee_id: attributes.fetch("remote_employee_id"),
        event_type: attributes.fetch("event_type"),
        effective_on: Date.iso8601(attributes.fetch("effective_on")),
        summary: attributes.fetch("summary"),
        payroll_impact: attributes.fetch("payroll_impact"),
        benefits_impact: attributes.fetch("benefits_impact"),
        compliance_impact: attributes.fetch("compliance_impact")
      )
    end
  end
end
