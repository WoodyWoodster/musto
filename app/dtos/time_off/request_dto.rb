module TimeOff
  RequestDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :department_name,
    :policy_name,
    :starts_on,
    :ends_on,
    :hours,
    :reason,
    :status,
    :reviewed_at
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        department_name: record.employee.department&.name,
        policy_name: record.time_off_policy.name,
        starts_on: record.starts_on,
        ends_on: record.ends_on,
        hours: record.hours,
        reason: record.reason,
        status: record.status,
        reviewed_at: record.reviewed_at
      )
    end

    def requested?
      status == "requested"
    end

    def approved?
      status == "approved"
    end

    def denied?
      status == "denied"
    end

    def duration_days
      (ends_on - starts_on).to_i + 1
    end
  end
end
