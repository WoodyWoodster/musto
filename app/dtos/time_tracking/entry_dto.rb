module TimeTracking
  EntryDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :work_date,
    :clock_in_at,
    :clock_out_at,
    :break_minutes,
    :payable_minutes,
    :payable_hours,
    :source,
    :status,
    :notes
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        department_name: record.employee.department&.name || "Unassigned",
        location_name: record.employee.work_location&.name || "No location",
        work_date: record.work_date,
        clock_in_at: record.clock_in_at,
        clock_out_at: record.clock_out_at,
        break_minutes: record.break_minutes,
        payable_minutes: record.duration_minutes,
        payable_hours: record.payable_hours,
        source: record.source,
        status: record.status,
        notes: record.notes
      )
    end

    def submitted?
      status == "submitted"
    end

    def approved?
      status == "approved"
    end
  end
end
