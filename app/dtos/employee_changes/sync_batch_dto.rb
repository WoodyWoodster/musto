module EmployeeChanges
  SyncBatchDto = Data.define(:batch_id, :generated_at, :requested_by, :status, :request_count, :employee_count, :payroll_impact_count, :benefits_impact_count, :holdback_count) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        request_count: totals.fetch("request_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        payroll_impact_count: totals.fetch("payroll_impact_count", 0),
        benefits_impact_count: totals.fetch("benefits_impact_count", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end
  end
end
