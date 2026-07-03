module EmployeeChanges
  SyncLineDto = Data.define(:request_id, :employee_id, :employee_name, :remote_employee_id, :request_type, :effective_on, :title, :payroll_impact, :benefits_impact, :compliance_impact, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        request_id: attributes.fetch("request_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        remote_employee_id: attributes.fetch("remote_employee_id"),
        request_type: attributes.fetch("request_type"),
        effective_on: Date.iso8601(attributes.fetch("effective_on")),
        title: attributes.fetch("title"),
        payroll_impact: attributes.fetch("payroll_impact"),
        benefits_impact: attributes.fetch("benefits_impact"),
        compliance_impact: attributes.fetch("compliance_impact"),
        status: attributes.fetch("status")
      )
    end
  end
end
