module Onboarding
  TaskDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :title,
    :category,
    :owner,
    :status,
    :due_on,
    :overdue
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        title: record.title,
        category: record.category,
        owner: record.owner,
        status: record.status,
        due_on: record.due_on,
        overdue: record.overdue?
      )
    end

    def complete?
      status == "complete"
    end

    def overdue?
      overdue
    end
  end
end
