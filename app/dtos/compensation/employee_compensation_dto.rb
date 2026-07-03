module Compensation
  EmployeeCompensationDto = Data.define(
    :employee_id,
    :employee_name,
    :title,
    :department_name,
    :location_name,
    :pay_type,
    :base_compensation_cents,
    :monthly_benefit_cents,
    :annual_benefit_cents,
    :adjustment_cents,
    :total_planned_cents,
    :accepted_enrollment_count,
    :pending_enrollment_count,
    :status,
    :status_reason
  )
end
