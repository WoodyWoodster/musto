module Scheduling
  ForecastLineDto = Data.define(:shift_id, :employee_id, :employee_name, :role, :department_name, :location_name, :starts_at, :ends_at, :net_minutes, :hourly_rate_cents, :labor_cost_cents, :status) do
    def self.from_hash(payload)
      new(
        shift_id: payload.fetch("shift_id", nil),
        employee_id: payload.fetch("employee_id", nil),
        employee_name: payload.fetch("employee_name", "Employee pending"),
        role: payload.fetch("role", "Shift"),
        department_name: payload.fetch("department_name", nil),
        location_name: payload.fetch("location_name", nil),
        starts_at: payload.fetch("starts_at", nil),
        ends_at: payload.fetch("ends_at", nil),
        net_minutes: payload.fetch("net_minutes", 0),
        hourly_rate_cents: payload.fetch("hourly_rate_cents", 0),
        labor_cost_cents: payload.fetch("labor_cost_cents", 0),
        status: payload.fetch("status", "forecast_ready")
      )
    end
  end
end
