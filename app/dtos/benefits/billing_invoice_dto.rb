module Benefits
  BillingInvoiceDto = Data.define(
    :id,
    :invoice_number,
    :carrier,
    :period_start_on,
    :period_end_on,
    :due_on,
    :status,
    :total_premium_cents,
    :employee_contribution_cents,
    :employer_contribution_cents,
    :variance_cents,
    :approved_at,
    :paid_at,
    :line_count
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        invoice_number: record.invoice_number,
        carrier: record.carrier,
        period_start_on: record.period_start_on,
        period_end_on: record.period_end_on,
        due_on: record.due_on,
        status: record.status,
        total_premium_cents: record.total_premium_cents,
        employee_contribution_cents: record.employee_contribution_cents,
        employer_contribution_cents: record.employer_contribution_cents,
        variance_cents: record.variance_cents,
        approved_at: record.approved_at,
        paid_at: record.paid_at,
        line_count: record.benefit_invoice_lines.size
      )
    end

    def approvable?
      !paid? && status != "approved"
    end

    def paid?
      status == "paid"
    end
  end
end
