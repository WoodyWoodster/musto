module Operations
  DepartmentDto = Data.define(:id, :name, :code, :employee_count, :budget_cents) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        code: record.code,
        employee_count: record.employees.size,
        budget_cents: record.budget_cents
      )
    end
  end
end
