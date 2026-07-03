module People
  DepartmentNodeDto = Data.define(:department_id, :department_name, :code, :manager_id, :manager_name, :employee_count, :status) do
    def self.from_record(record)
      new(
        department_id: record.id,
        department_name: record.name,
        code: record.code,
        manager_id: record.manager_id,
        manager_name: record.manager&.full_name,
        employee_count: record.employees.active.count,
        status: record.manager_id.present? ? "ready" : "needs_review"
      )
    end
  end
end
