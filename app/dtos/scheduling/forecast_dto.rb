module Scheduling
  ForecastDto = Data.define(:batch_id, :status, :generated_at, :requested_by, :payroll_run_id, :line_count, :employee_count, :holdback_count, :total_minutes, :total_labor_cents) do
    def self.from_hash(payload)
      totals = payload.fetch("totals", {})

      new(
        batch_id: payload.fetch("batch_id", nil),
        status: payload.fetch("status", "empty"),
        generated_at: payload.fetch("generated_at", nil),
        requested_by: payload.fetch("requested_by", nil),
        payroll_run_id: payload.fetch("payroll_run_id", nil),
        line_count: totals.fetch("line_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        total_minutes: totals.fetch("total_minutes", 0),
        total_labor_cents: totals.fetch("total_labor_cents", 0)
      )
    end
  end
end
