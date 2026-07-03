module PayrollCalendar
  RunDto = Data.define(:id, :period_start_on, :period_end_on, :pay_date, :status, :gross_pay_cents, :adjustment_cents, :deduction_cents, :estimated_tax_cents, :estimated_net_pay_cents, :employee_count, :statement_count) do
    def self.from_record(record)
      return unless record

      new(
        id: record.id,
        period_start_on: record.period_start_on,
        period_end_on: record.period_end_on,
        pay_date: record.pay_date,
        status: record.status,
        gross_pay_cents: record.gross_pay_cents,
        adjustment_cents: record.total_adjustments_cents,
        deduction_cents: record.total_deductions_cents,
        estimated_tax_cents: record.estimated_tax_cents,
        estimated_net_pay_cents: record.estimated_net_pay_cents,
        employee_count: record.employer.employees.active.count,
        statement_count: record.pay_statements.size
      )
    end

    def finalized?
      status == "finalized"
    end
  end
end
