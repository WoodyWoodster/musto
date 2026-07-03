module PayrollFunding
  BatchDto = Data.define(:batch_id, :generated_at, :status, :requested_by, :payroll_run_id, :pay_date, :credit_count, :employee_count, :holdback_count, :total_cents, :debit_account_name) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys
      debit = attributes.fetch("debit", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        status: attributes.fetch("status"),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        payroll_run_id: attributes.fetch("payroll_run_id"),
        pay_date: Date.iso8601(attributes.fetch("pay_date")),
        credit_count: totals.fetch("credit_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        total_cents: totals.fetch("total_cents", 0),
        debit_account_name: debit.fetch("account_name", nil)
      )
    end
  end
end
