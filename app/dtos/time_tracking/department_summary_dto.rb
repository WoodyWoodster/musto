module TimeTracking
  DepartmentSummaryDto = Data.define(
    :department_id,
    :department_name,
    :employee_count,
    :approved_minutes,
    :submitted_minutes,
    :overtime_minutes,
    :approval_rate,
    :status
  )
end
