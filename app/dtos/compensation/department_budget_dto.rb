module Compensation
  DepartmentBudgetDto = Data.define(
    :department_id,
    :department_name,
    :code,
    :employee_count,
    :budget_cents,
    :base_compensation_cents,
    :adjustment_cents,
    :annual_benefit_cents,
    :planned_spend_cents,
    :remaining_cents,
    :utilization_percent,
    :status
  )
end
