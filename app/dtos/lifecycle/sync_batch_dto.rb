module Lifecycle
  SyncBatchDto = Data.define(
    :batch_id,
    :generated_at,
    :status,
    :requested_by,
    :event_count,
    :employee_count,
    :holdback_count,
    :benefit_impact_count,
    :payroll_impact_count
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        status: attributes.fetch("status"),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        event_count: totals.fetch("event_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        benefit_impact_count: totals.fetch("benefit_impact_count", 0),
        payroll_impact_count: totals.fetch("payroll_impact_count", 0)
      )
    end
  end
end
