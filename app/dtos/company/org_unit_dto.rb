module Company
  OrgUnitDto = Data.define(:id, :name, :code, :employee_count, :budget_cents, :manager_name, :status) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        code: record.code,
        employee_count: record.employees.size,
        budget_cents: record.budget_cents,
        manager_name: record.manager&.full_name,
        status: record.manager.present? ? "ready" : "needs_review"
      )
    end
  end
end
