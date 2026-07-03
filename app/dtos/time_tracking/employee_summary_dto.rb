module TimeTracking
  EmployeeSummaryDto = Data.define(
    :employee_id,
    :employee_name,
    :department_name,
    :pay_type,
    :entry_count,
    :approved_minutes,
    :submitted_minutes,
    :overtime_minutes,
    :regular_minutes,
    :status
  )
end
