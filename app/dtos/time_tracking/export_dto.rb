module TimeTracking
  ExportDto = Data.define(
    :export_id,
    :generated_at,
    :status,
    :requested_by,
    :payroll_run_id,
    :line_count,
    :approved_minutes,
    :holdback_count,
    :total_gross_cents
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        export_id: attributes.fetch("export_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        status: attributes.fetch("status"),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        payroll_run_id: attributes.fetch("payroll_run_id", nil),
        line_count: totals.fetch("line_count", 0),
        approved_minutes: totals.fetch("approved_minutes", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        total_gross_cents: totals.fetch("total_gross_cents", 0)
      )
    end
  end
end
