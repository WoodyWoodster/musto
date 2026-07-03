module Reports
  DepartmentCostDto = Data.define(
    :department_id,
    :department_name,
    :employee_count,
    :payroll_cents,
    :benefit_cost_cents,
    :deduction_cents,
    :risk_count,
    :status
  )
end
