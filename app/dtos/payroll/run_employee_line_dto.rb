module Payroll
  RunEmployeeLineDto = Data.define(
    :employee_id,
    :employee_name,
    :title,
    :gross_pay_cents,
    :adjustments_cents,
    :deductions_cents,
    :estimated_tax_cents,
    :estimated_net_pay_cents,
    :status
  )
end
