module Operations
  EnrollmentDto = Data.define(:id, :employee_name, :benefit_plan_name, :coverage_level, :effective_on, :status) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_name: record.employee.full_name,
        benefit_plan_name: record.benefit_plan.name,
        coverage_level: record.coverage_level,
        effective_on: record.effective_on,
        status: record.status
      )
    end
  end
end
