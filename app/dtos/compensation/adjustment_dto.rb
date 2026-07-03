module Compensation
  AdjustmentDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :department_name,
    :payroll_run_id,
    :pay_date,
    :adjustment_type,
    :description,
    :amount_cents,
    :taxable,
    :status
  ) do
    def taxable?
      taxable
    end
  end
end
