module Scheduling
  ForecastHoldbackDto = Data.define(:shift_id, :employee_name, :role, :starts_at, :status, :reason) do
    def self.from_hash(payload)
      new(
        shift_id: payload.fetch("shift_id", nil),
        employee_name: payload.fetch("employee_name", "Open shift"),
        role: payload.fetch("role", "Shift"),
        starts_at: payload.fetch("starts_at", nil),
        status: payload.fetch("status", "needs_review"),
        reason: payload.fetch("reason", "Needs review")
      )
    end
  end
end
