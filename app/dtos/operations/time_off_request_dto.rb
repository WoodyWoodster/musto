module Operations
  TimeOffRequestDto = Data.define(:id, :employee_name, :policy_name, :starts_on, :ends_on, :hours, :reason, :status) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_name: record.employee.full_name,
        policy_name: record.time_off_policy.name,
        starts_on: record.starts_on,
        ends_on: record.ends_on,
        hours: record.hours,
        reason: record.reason,
        status: record.status
      )
    end

    def requested?
      status == "requested"
    end
  end
end
