module Benefits
  BillingLineDto = Data.define(
    :id,
    :invoice_id,
    :employee_id,
    :employee_name,
    :plan_name,
    :plan_category,
    :coverage_level,
    :amount_cents,
    :expected_premium_cents,
    :expected_payroll_deduction_cents,
    :employee_contribution_cents,
    :employer_contribution_cents,
    :variance_cents,
    :status
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        invoice_id: record.benefit_invoice_id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        plan_name: record.benefit_plan.name,
        plan_category: record.benefit_plan.category,
        coverage_level: record.coverage_level,
        amount_cents: record.amount_cents,
        expected_premium_cents: record.expected_premium_cents,
        expected_payroll_deduction_cents: record.expected_payroll_deduction_cents,
        employee_contribution_cents: record.employee_contribution_cents,
        employer_contribution_cents: record.employer_contribution_cents,
        variance_cents: record.variance_cents,
        status: record.status
      )
    end

    def matched?
      status == "matched"
    end

    def blocked?
      status.in?([ "variance", "missing_deduction", "needs_review" ])
    end
  end
end
