module Taxes
  PayrollLiabilityDto = Data.define(
    :payroll_run_id,
    :period_label,
    :pay_date,
    :gross_pay_cents,
    :adjustment_cents,
    :deduction_cents,
    :employee_tax_cents,
    :employer_tax_cents,
    :total_liability_cents,
    :status
  )
end
