module Employers
  RosterEmployeeDto = Data.define(
    :id,
    :full_name,
    :title,
    :department_name,
    :work_location_name,
    :compensation_cents,
    :pay_type
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        full_name: record.full_name,
        title: record.title,
        department_name: record.department&.name,
        work_location_name: record.work_location&.name,
        compensation_cents: record.compensation_cents,
        pay_type: record.pay_type
      )
    end
  end
end
