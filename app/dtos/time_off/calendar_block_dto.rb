module TimeOff
  CalendarBlockDto = Data.define(:id, :employee_name, :policy_name, :starts_on, :ends_on, :hours, :status) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_name: record.employee.full_name,
        policy_name: record.time_off_policy.name,
        starts_on: record.starts_on,
        ends_on: record.ends_on,
        hours: record.hours,
        status: record.status
      )
    end

    def date_range
      return starts_on.strftime("%b %-d") if starts_on == ends_on

      "#{starts_on.strftime('%b %-d')} - #{ends_on.strftime('%b %-d')}"
    end
  end
end
