module Operations
  OnboardingTaskDto = Data.define(:id, :title, :status, :employee_name, :category, :due_on) do
    def self.from_record(record)
      new(
        id: record.id,
        title: record.title,
        status: record.status,
        employee_name: record.employee.full_name,
        category: record.category,
        due_on: record.due_on
      )
    end

    def complete?
      status == "complete"
    end
  end
end
