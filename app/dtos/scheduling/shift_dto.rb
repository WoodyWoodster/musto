module Scheduling
  ShiftDto = Data.define(:id, :employee_id, :employee_name, :employee_title, :role, :department_name, :location_name, :status, :starts_at, :ends_at, :break_minutes, :net_minutes, :hourly_rate_cents, :labor_cost_cents, :readiness_status, :readiness_reason) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee&.full_name || "Open shift",
        employee_title: record.employee&.title,
        role: record.role,
        department_name: record.department&.name,
        location_name: record.work_location&.name,
        status: record.status,
        starts_at: record.starts_at,
        ends_at: record.ends_at,
        break_minutes: record.break_minutes,
        net_minutes: record.net_minutes,
        hourly_rate_cents: record.hourly_rate_cents,
        labor_cost_cents: record.labor_cost_cents,
        readiness_status: readiness_status(record),
        readiness_reason: readiness_reason(record)
      )
    end

    def open_shift?
      employee_id.blank?
    end

    def publishable?
      status == "draft"
    end

    private_class_method def self.readiness_status(record)
      return "coverage_gap" if record.open_shift?
      return "needs_review" if record.draft?
      return "missed" if record.missed?
      return "closed" if record.canceled?

      "forecast_ready"
    end

    private_class_method def self.readiness_reason(record)
      return "Shift needs an assigned employee" if record.open_shift?
      return "Draft shift must be published before employees see it" if record.draft?
      return "Missed shift needs manager review before payroll" if record.missed?
      return "Canceled shift is excluded from payroll forecast" if record.canceled?

      "Ready for schedule and payroll forecast"
    end
  end
end
