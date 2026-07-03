module Operations
  EnrollmentDto = Data.define(
    :id,
    :employee_id,
    :benefit_plan_id,
    :employee_name,
    :benefit_plan_name,
    :monthly_premium_cents,
    :coverage_level,
    :effective_on,
    :status
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        benefit_plan_id: record.benefit_plan_id,
        employee_name: record.employee.full_name,
        benefit_plan_name: record.benefit_plan.name,
        monthly_premium_cents: record.benefit_plan.monthly_premium_cents,
        coverage_level: record.coverage_level,
        effective_on: record.effective_on,
        status: record.status
      )
    end
  end
end
